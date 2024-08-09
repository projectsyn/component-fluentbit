local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.fluentbit;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App(inv.parameters._instance, params.namespace) {
  spec+: {
    source+: {
      path: 'manifests/fluentbit/' + inv.parameters._instance,
    },
  },
};

{
  [inv.parameters._instance]: app,
}
