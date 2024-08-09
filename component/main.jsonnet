local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.fluentbit;
local instanceName = inv.parameters._instance;

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
  // Construct array of arrays for all config entries then flatten the array.
  //
  // This allows us to specify repeatable config entries in YAML as keys
  // pointing to arrays, e.g. for the systemd input we can then have the
  // following configuration in the component parameters:
  //
  //   Systemd_Filter:
  //     - _SYSTEMD_UNIT=kubelet.service
  //     - _SYSTEMD_UNIT=docker.service
  //
  // In the resulting fluentbit config, this will be transformed into:
  //
  //   Systemd_Filter _SYSTEMD_UNIT=kubelet.service
  //   Systemd_Filter _SYSTEMD_UNIT=docker.service
  //
  // Note that the logic also degrades gracefully when a user specifies a
  // repeatable option as `key: value`.
  local entries = std.flattenArrays(std.prune([
    // explicitly add 'Name' key as first element of section
    if realname != '' then [ std.format('Name %s', realname) ],
  ] + [
    local value = realcfg[key];

    if std.isArray(value) then
      [
        std.format('%s %s', [ key, v ])
        for v in value
      ]
    else
      [ std.format('%s %s', [ key, value ]) ]
    for key in std.objectFields(realcfg)
  ]));
  local entriesStr = std.join('\n    ', entries);
  std.format('%s\n    %s', [ header, entriesStr ]);


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

local multiline_parsers = std.join('\n', [
  render_fluentbit_cfg('MULTILINE_PARSER', elem, params.config.multiline_parsers[elem])
  for elem in std.objectFields(params.config.multiline_parsers)
]);

local filters = std.join('\n', [
  render_fluentbit_cfg('FILTER', elem, params.config.filters[elem])
  for elem in std.sort(std.objectFields(params.config.filters))
]);

local userParsersFile =
  local userParsers = com.getValueOrDefault(
    params.config.service,
    'Parsers_File',
    []
  );
  local uparsers =
    if std.isArray(userParsers) then
      userParsers
    else
      [ userParsers ];
  // Remove duplicates in `userParsers`, preserving the order of the defined
  // parser files. Additionally we remove 'parsers.conf' which is included
  // unconditionally below.
  std.foldl(
    function(parsers, p)
      if p != 'parsers.conf' && !std.member(parsers, p) then
        parsers + [ p ]
      else
        parsers,
    uparsers,
    []
  );

local all_parsers =
  local ps = (
    if std.length(parsers) > 0 then [ parsers ] else []
  ) + (
    if std.length(multiline_parsers) > 0 then [ multiline_parsers ] else []
  );
  std.join('\n', ps);

local customParsersFragment =
  if std.length(all_parsers) > 0 then
    {
      Parsers_File+: [
        'custom_parsers.conf',
      ],
    }
  else
    {};

local serviceCfg =
  {
    Daemon: 'Off',
    Plugins_File: 'plugins.conf',
    // Default configuration: always use fluentbit default parsers.conf
    Parsers_File:
      [ 'parsers.conf' ] +
      // Add in any parser files configured by the user.
      userParsersFile,
    HTTP_Listen: '0.0.0.0',
    HTTP_Server: 'On',
    HTTP_Port: params.monitoring.metricsPort,
  } +
  // Remove Parsers_File config from user provided service config,
  // we already add any Parsers_File configs provided by the user in the
  // dict above.
  std.prune(params.config.service { Parsers_File: null }) +
  // Add Parsers_File entry for custom_parsers.conf, if any parsers are
  // defined in the config hierarchy.
  customParsersFragment;


local service = render_fluentbit_cfg('SERVICE', '', serviceCfg);

local configmap = kube.ConfigMap(params.configMapName) {
  metadata+: {
    namespace: params.namespace,
    labels+: {
      'app.kubernetes.io/name': 'fluent-bit',
      'app.kubernetes.io/instance': instanceName,
      'app.kubernetes.io/version':
        std.split(params.images.fluent_bit.tag, '@')[0],
      'app.kubernetes.io/component': 'fluent-bit',
      'app.kubernetes.io/managed-by': 'commodore',
    },
  },
  data: {
    'fluent-bit.conf': std.join('\n', [ service, filters, inputs, outputs ]),
    'custom_parsers.conf': if std.length(all_parsers) > 0 then all_parsers else '',
  },
};

local secret = kube.Secret(instanceName) {
  metadata+: {
    labels+: {
      'app.kubernetes.io/name': 'fluent-bit',
      'app.kubernetes.io/instance': instanceName,
      'app.kubernetes.io/component': 'fluent-bit',
      'app.kubernetes.io/managed-by': 'commodore',
    },
  },
  stringData: {
    [s]: params.secrets[s]
    for s in std.objectFields(params.secrets)
  },
};

{
  [if params.createNamespace then '00_namespace']: kube.Namespace(params.namespace),
  [if std.length(params.secrets) > 0 then '10_custom_secret']: secret,
  '10_custom_config': configmap,
  [if params.monitoring.enabled then '20_service_monitor']:
    kube._Object('monitoring.coreos.com/v1', 'ServiceMonitor', 'fluent-bit') {
      metadata+: {
        namespace: params.namespace,
        labels+: {
          'app.kubernetes.io/name': 'fluent-bit',
          'app.kubernetes.io/instance': instanceName,
          'app.kubernetes.io/version':
            std.split(params.images.fluent_bit.tag, '@')[0],
          'app.kubernetes.io/component': 'fluent-bit',
          'app.kubernetes.io/managed-by': 'commodore',
        },
      },
      spec: {
        endpoints: [ {
          port: 'http',
          path: '/api/v1/metrics/prometheus',
        } ],
        selector: {
          matchLabels: {
            'app.kubernetes.io/name': 'fluent-bit',
            'app.kubernetes.io/instance': instanceName,
          },
        },
      },
    },
}
