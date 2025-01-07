local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.fluentbit;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App(inv.parameters._instance, params.namespace);

local appPath =
  local project = std.get(std.get(app, 'spec', {}), 'project', 'syn');
  if project == 'syn' then 'apps' else 'apps-%s' % project;

{
  ['%s/%s' % [ appPath, inv.parameters._instance ]]: app,
}
