local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();

// The hiera parameters for the component
local params = inv.parameters.fluentbit;
local instanceName = inv.parameters._instance;

local common = {
  fullnameOverride: instanceName,
  podAnnotations: params.annotations,
  image: {
    repository: params.images.fluent_bit.image,
    tag: params.images.fluent_bit.tag,
  },
  existingConfigMap: params.configMapName,
  service: {
    port: params.monitoring.metricsPort,
  },
  podSecurityPolicy: {
    create: params.psp_enabled,
  },
  serviceMonitor: {
    enabled: params.monitoring.enabled,
  },
  prometheusRule: {
    enabled: false,
  },
  tolerations: params.tolerations,
  extraVolumes: params.extraVolumes,
  extraVolumeMounts: params.extraVolumeMounts,
};

local replicaCount = std.get(params.helm_values, 'replicaCount', 1);
local multiReplica = replicaCount > 1;

local computed = {
  podDisruptionBudget: {
    enabled: multiReplica,
  },
  affinity: {
    podAntiAffinity: {
      preferredDuringSchedulingIgnoredDuringExecution: [ {
        weight: 100,
        podAffinityTerm: {
          topologyKey: 'kubernetes.io/hostname',
          labelSelector: {
            matchLabels: {
              'app.kubernetes.io/instance': instanceName,
              'app.kubernetes.io/name': 'fluent-bit',
            },
          },
        },
      } ],
    },
  },
};

{
  [instanceName + '-common']: common,
  [instanceName + '-overrides']: params.helm_values,
  [instanceName + '-computed']: computed,
}
