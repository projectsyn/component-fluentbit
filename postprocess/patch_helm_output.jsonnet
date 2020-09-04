local com = import 'lib/commodore.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = com.inventory();
local params = inv.parameters.fluentbit;

local chart_output_dir = std.extVar('output_path');

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

local fixup_obj(obj) =
  if obj.kind == 'DaemonSet' then
    fix_container_port(obj)
  else
    obj;

local fixup(obj_file) =
  local objs = std.prune(com.yaml_load_all(obj_file));
  [fixup_obj(obj) for obj in objs];

{
  [stem(elem)]: fixup(input_file(elem))
  for elem in chart_files
}
