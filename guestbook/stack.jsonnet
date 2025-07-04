local kube = import 'vendor/kube-libsonnet/kube.libsonnet';

local waves = {
  accessories: "0",
  application: "1",
};

local names = {
  app: 'guestbook',
  ui: $.app + '-ui',
  redis_operator: 'redis-operator',
};

local stack = {
  redis_operator: kube.Deployment(names.redis_operator) {
    metadata+: {
      annotations+: {
        "argocd.argoproj.io/sync-wave": waves.accessories,
      },
    },
    spec+: {
      replicas: 1,
      template+: {
        spec+: {
          restartPolicy: "Always",
          containers_+: {
            ui_container: kube.Container(names.redis_operator) {
              image: 'powerhome/redis-operator:v4.3.0',
              env_+: {
                name: 'WATCH_NAMESPACE',
                valueFrom: {
                  fieldRef: {
                    fieldPath: 'metadata.namespace',
                  },
                },
              },
              securityContext+: {
                readOnlyRootFilesystem: true,
                runAsNonRoot: true,
                runAsUser: 1000,
              },
              resources: {
                requests: { cpu: '10m', memory: '50Mi' },
                limits: { memory: '50Mi'},
              },
              ports_+: {
                metrics: { containerPort: 9710 },
              },
            },
          },
        },
      },
    },
  },
  ui_deployment: kube.Deployment(names.ui) {
    metadata+: {
      annotations+: {
        "argocd.argoproj.io/sync-wave": waves.application,
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
  items_+: stack,
}
