local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.fluentbit;

local render_fluentbit_cfg(type, name, cfg) =
  local header = '[%s]' % std.asciiUpper(type);
  // Use 'Name' entry if there is one in object `cfg`, otherwise use function
  // argument.
  local realname =
    if std.objectHas(cfg, 'Name') then
      cfg.Name
    else
      name;
  // remove 'Name' entry from `cfg` object, if it exists
  local realcfg = std.prune(cfg { Name: null });
  local entries = std.prune([
    // explicitly add 'Name' key as first element of section
    if realname != '' then std.format('Name %s', realname),
  ] + [
    std.format('%s %s', [key, realcfg[key]])
    for key in std.objectFields(realcfg)
  ]);
  local entriesStr = std.join('\n    ', entries);
  std.format('%s\n    %s', [header, entriesStr]);


local inputs = std.join('\n', [
  render_fluentbit_cfg('INPUT', elem, params.config.inputs[elem])
  for elem in std.objectFields(params.config.inputs)
]);

local outputs = std.join('\n', [
  render_fluentbit_cfg('OUTPUT', elem, params.config.outputs[elem])
  for elem in std.objectFields(params.config.outputs)
]);

local parsers = std.join('\n', [
  render_fluentbit_cfg('PARSER', elem, params.config.parsers[elem])
  for elem in std.objectFields(params.config.parsers)
]);

local filters = std.join('\n', [
  render_fluentbit_cfg('FILTER', elem, params.config.filters[elem])
  for elem in std.sort(std.objectFields(params.config.filters))
]);

local serviceCfg = {
  Daemon: 'Off',
  Plugins_File: 'plugins.conf',
  HTTP_Listen: '0.0.0.0',
  HTTP_Server: 'On',
  HTTP_Port: params.monitoring.metricsPort,
} + params.config.service;

local service = render_fluentbit_cfg('SERVICE', '', serviceCfg);

local configmap = kube.ConfigMap(params.configMapName) {
  metadata+: {
    namespace: params.namespace,
    labels+: {
      'app.kubernetes.io/name': 'fluent-bit',
      'app.kubernetes.io/instance': 'fluent-bit-cluster',
      'app.kubernetes.io/version':
        std.split(params.images.fluent_bit.tag, '@')[0],
      'app.kubernetes.io/component': 'fluent-bit',
      'app.kubernetes.io/managed-by': 'commodore',
    },
  },
  data: {
    'syn-fluent-bit.conf': std.join('\n', [service, parsers, filters, inputs, outputs]),
  },
};

{
  '10_custom_config': configmap,
  [if params.monitoring.enabled then '20_service_monitor']:
    kube._Object('monitoring.coreos.com/v1', 'ServiceMonitor', 'fluent-bit') {
      metadata+: {
        namespace: params.namespace,
        labels+: {
          'app.kubernetes.io/name': 'fluent-bit',
          'app.kubernetes.io/instance': 'fluent-bit-cluster',
          'app.kubernetes.io/version':
            std.split(params.images.fluent_bit.tag, '@')[0],
          'app.kubernetes.io/component': 'fluent-bit',
          'app.kubernetes.io/managed-by': 'commodore',
        },
      },
      spec: {
        endpoints: [{
          port: 'http',
          path: '/api/v1/metrics/prometheus',
        }],
        selector: {
          matchLabels: {
            'app.kubernetes.io/name': 'fluent-bit',
            'app.kubernetes.io/instance': 'fluent-bit',
          },
        },
      },
    },
}
