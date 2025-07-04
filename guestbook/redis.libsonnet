local kube = import 'vendor/kube-libsonnet/kube.libsonnet';

local names = {
  operator: 'redis-operator',
};

local defaults = {
  operator: {
    name: 'redis-operator',
    image: 'powerhome/redis-operator:v4.3.0',
  },
  redis: {
    name: 'redis',
  },
};

local Operator(args) =
  kube.Deployment(names.operator) {
    metadata+: {
      annotations+: {
        'argocd.argoproj.io/hook': 'PreSync',
        [if args.sync_wave != null then 'argocd.argoproj.io/sync-wave']: args.sync_wave,
      },
    },
    spec+: {
      replicas: 1,
      template+: {
        spec+: {
          serviceAccountName: 'redis-operator',
          restartPolicy: 'Always',
          containers_+: {
            ui_container: kube.Container(names.operator) {
              image: 'powerhome/redis-operator:v4.3.0',
              env_+: {
                WATCH_NAMESPACE: {
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
  };

local CustomResource(args) =
  local name = if args.name != null then args.name else defaults.redis.name;
  {
    apiVersion: 'databases.spotahome.com/v1',
    kind: 'RedisFailover',
    metadata+: {
      name: name,
      labels: {
        'app.kubernetes.io/name': name,
      },
      annotations+: {
        [if args.sync_wave != null then 'argocd.argoproj.io/sync-wave']: args.sync_wave,
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
      },
      haproxy: {
        replicas: 2,
        resources: {
          requests: { cpu: '100m', memory: '100Mi' },
          limits: { memory: '500Mi' },
        },
      },
    },
  };

{
  Operator:: Operator,
  CustomResource:: CustomResource,
}
