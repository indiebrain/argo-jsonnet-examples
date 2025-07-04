local kube = import 'vendor/kube-libsonnet/kube.libsonnet';

local waves = {
  accessories: '0',
  application: '1',
};

local names = {
  app: 'guestbook',
  ui: $.app + '-ui',
  redis_operator: 'redis-operator',
  redis_cache: 'redis-cache',
};

local accessories = {
  redis_operator: kube.Deployment(names.redis_operator) {
    metadata+: {
      annotations+: {
        'argocd.argoproj.io/hook': 'PreSync',
        'argocd.argoproj.io/sync-wave': waves.accessories,
      },
    },
    spec+: {
      replicas: 1,
      template+: {
        spec+: {
          serviceAccountName: 'redis-operator',
          restartPolicy: 'Always',
          containers_+: {
            ui_container: kube.Container(names.redis_operator) {
              image: 'powerhome/redis-operator:v4.3.0',
              env_+: {
                'WATCH_NAMESPACE': {
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
                limits: { memory: '50Mi' },
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
  redis_cache: {
    apiVersion: 'databases.spotahome.com/v1',
    kind: 'RedisFailover',
    metadata+: {
      name: names.redis_cache,
      labels: {
        'app.kubernetes.io/name': names.redis_cache,
      },
      annotations+: {
        'argocd.argoproj.io/sync-wave': waves.accessories,
      },
    },
    spec+: {
      labelWhitelist: ['^redisfailovers.databases.spotahome.com.*'],
      networkPolicyNsList: [
        {
          matchLabelKey: 'app.kubernetes.io/name',
          matchLabelValue: 'guestbook-libsonnet',
        },
      ],
      redis: {
        image: 'redis:7.2.4-alpine',
        port: 6379,
        replicas: 2,
        resources: {
          requests: { cpu: '100m', memory: '500Mi' },
          limits: { memory: '500Mi' },
        },
        storage: {
          keepAfterDeletion: false,
          persistentVolumeClaim: {
            metadata: {
              name: 'redis-data',
            },
            spec: {
              accessModes: ['ReadWriteOnce'],
              resources: {
                requests: {
                  storage: '1Gi',
                },
              },
            },
          },
        },
        exporter: {
          enabled: true,
          image: 'docker.io/oliver006/redis_exporter:v1.50.0-alpine',
          args: ['--web.telemetry-path', '/metrics'],
          env: [{ name: 'REDIS_EXPORTER_LOG_FORMAT', value: 'txt' }],
        },
        customConfig: ['appendonly yes'],
      },
      sentinel: {
        port: 6830,
        replicas: 3,
        resources: {
          requests: { cpu: '100m', memory: '500Mi' },
          limits: { memory: '500Mi' },
        },
        exporter: {
          enabled: true,
          image: 'docker.io/leominov/redis_sentinel_exporter:1.7.1',
        },
        haproxy: {
          replicas: 2,
          resources: {
            requests: { cpu: '100m', memory: '100Mi' },
            limits: { memory: '500Mi' },
          },
        },
      },
    },
  },
};

local stack = {
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
  items_+: accessories + stack,
}
