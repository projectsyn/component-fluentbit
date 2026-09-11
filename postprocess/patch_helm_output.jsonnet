local com = import 'lib/commodore.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = com.inventory();
local params = inv.parameters.fluentbit;

local chart_output_dir = std.extVar('output_path');

// Grab custom configmap to add a hash of the contents as annotation to the
// DaemonSet. This will trigger fluentbit restarts if the config changes
local configmap_file = chart_output_dir + '/../../../10_custom_config.yaml';
local configmap = std.prune(com.yaml_load_all(configmap_file))[0];
local configmap_contents_hash = std.md5(configmap.data['fluent-bit.conf']);

local list_dir(dir, basename=true) =
  std.native('list_dir')(dir, basename);

local chart_files = list_dir(chart_output_dir);

local input_file(elem) = chart_output_dir + '/' + elem;
local stem(elem) =
  local elems = std.split(elem, '.');
  std.join('.', elems[:std.length(elems) - 1]);

local fix_container_port(ds) =
  local ports = ds.spec.template.spec.containers[0].ports;
  local fixedports = [
    if p.name == 'http' then
      p { containerPort: params.monitoring.metricsPort }
    else
      p
    for p in ports
  ];
  ds {
    spec+: {
      template+: {
        metadata+: {
          annotations+: {
            'checksum/syn-config': configmap_contents_hash,
          },
        },
        spec+: {
          containers: [
            ds.spec.template.spec.containers[0] {
              ports: fixedports,
            },
          ],
        },
      },
    },
  };

local add_pod_anti_affinity(workload) =
  workload {
    spec+: {
      template+: {
        spec+: {
          affinity+: {
            podAntiAffinity+: {
              preferredDuringSchedulingIgnoredDuringExecution+: [ {
                weight: 100,
                podAffinityTerm: {
                  topologyKey: 'kubernetes.io/hostname',
                  labelSelector: {
                    matchLabels: workload.spec.selector.matchLabels,
                  },
                },
              } ],
            },
          },
        },
      },
    },
  };

local fixup_obj(obj) =
  if obj.kind == 'DaemonSet' || obj.kind == 'Deployment' then
    add_pod_anti_affinity(
      if obj.kind == 'DaemonSet' then fix_container_port(obj) else obj
    )
  else
    obj;

local fixup(obj_file) =
  local objs = std.prune(com.yaml_load_all(obj_file));
  [ fixup_obj(obj) for obj in objs ];

local rendered_objs = [
  obj
  for elem in chart_files
  for obj in std.prune(com.yaml_load_all(input_file(elem)))
];

local has_pdb = std.length([
  obj
  for obj in rendered_objs
  if obj.kind == 'PodDisruptionBudget'
]) > 0;

local pdbs = [
  obj
  for obj in rendered_objs
  if obj.kind == 'Deployment' && obj.spec.replicas > 1 && !has_pdb
];

local pdb_obj(deployment) = {
  apiVersion: 'policy/v1',
  kind: 'PodDisruptionBudget',
  metadata: {
    name: deployment.metadata.name,
    namespace: params.namespace,
  },
  spec: {
    maxUnavailable: params.podDisruptionBudget.maxUnavailable,
    selector: {
      matchLabels: deployment.spec.selector.matchLabels,
    },
  },
};

{
  [stem(elem)]: fixup(input_file(elem))
  for elem in chart_files
} + {
  ['pdb-' + pdb.metadata.name]: [ pdb_obj(pdb) ]
  for pdb in pdbs
}
