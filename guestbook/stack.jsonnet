local redis = import 'lib/redis.libsonnet';
local kube = import 'vendor/kube-libsonnet/kube.libsonnet';

local waves = {
  accessories: '0',
  application: '1',
};

local names = {
  app: 'guestbook',
  ui: $.app + '-ui',
};

local stack = {
  redis_operator: redis.Operator({ sync_wave: waves.accessories }),
  redis_cache: redis.CustomResource({ name: 'cache', sync_wave: waves.accessories }),
  ui_deployment: kube.Deployment(names.ui) {
    metadata+: {
      annotations+: {
        'argocd.argoproj.io/sync-wave': waves.application,
      },
    },
    spec+: {
      replicas: 1,
      template+: {
        spec+: {
          containers_+: {
            ui_container: kube.Container(names.ui) {
              image: 'gcr.io/google-samples/gb-frontend:v5',
              ports_+: { http: { containerPort: 80 } },
            },
          },
        },
      },
    },
  },

  ui_service: kube.Service(names.ui) {
    target_pod: $.ui_deployment.spec.template,
  },
};

kube.List() {
  items_+:
    stack,
}
