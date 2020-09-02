local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.fluentbit;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('fluentbit', params.namespace);

{
  'fluentbit': app,
}
