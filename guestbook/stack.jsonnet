local kube = import 'vendor/kube-libsonnet/kube.libsonnet';

local names = {
  app: 'guestbook',
  ui:  $['app'] + '-ui',
};

local stack = {
  ui_deployment: kube.Deployment(names.ui) {
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
