# Microservices

This chart is a template for a simple microservice with some configurable options.

Below you can see the instructions of how to use it and configure it.
If you need more details and examples of configuration, check the `values.yaml` file.

## TL;DR

```console
helm install <release-name> charts/microservice
```
or

```console
helm install <release-name> oci://nursa-com.github.io/charts/microservice
```

## Introduction
Helm charts are groups of Kubernetes resources, with customizable behavior. The behavior is defined in the values files, check `values.yaml` of each chart to validate the default values and the options to customize the usage.

The charts in this repository are public, and easily downloaded and reused. We recommend the usage of this chart as a [depencency](https://helm.sh/docs/helm/helm_dependency/) of other charts, but not necessarily.

## Prerequisites

- Kubernetes 1.26+ (1.29+ to enable the opt-in AlloyDB Auth Proxy sidecar, which is a native sidecar; prod GKE runs 1.33)
- Helm 3.8.0+

## Using the Chart in a microservice

Add the repository to your local shell. To name it `nursa` use the following command:

```console
helm add repo nursa https://nursa-com.github.io/charts
```

To install the chart with the release name `my-app` using the:

```console
helm install my-app oci://nursa-com.github.io/charts/microservice
```

> Note: This installation sets the default values from `values.yaml`.

> **Tip**: List all releases using `helm list`

## Updating this chart
To update this repo and publish a new chart, 2 things are required:
- new changes to the chart merged to the `main` branch
- a new version is updated in the `Chart.yaml` (for intance, update it from `version: 1.8.0` to `version: 1.9.0`)

If the 2 conditions are met, a new automation will be triggered that will create a new release in Github with the corresponding version. Also, a new commit to the branch `gh-pages` will be added updating the `index.html` file with the new tarball file in its list, so helm clients know that there is a new version available.

If you are using this chart as a dependency, you can set the dependency like the following. This way, if the update was a patch/minor version, your chart will be automatically updated with the new features at the next deployment. Major changes will be applied when breaking changes are introduced.
```
dependencies:
  - name: microservice
    version: "1.x"
    repository: "https://nursa-com.github.io/charts"
```
## Configuration and installation details

### Customize your implementation
To customize your implementation, you should update the values as described in the `values.yaml` file. If you are using this chart as a dependency, you can create a new values file in the parent chart, and customize the behavior of this chart like the following example:

```
microservice:
  parameters: {}
  image: my-custom-image
  image_tag: my-custom-tag
  ...
  ...
  ...
  any_parameter_to_override_from_default: custom value
```

If you need to update the values dinamically, such as in CI/CD for an image_tag, it's possible to set values in the helm commands, for instance:
```
helm install <release-name> oci://nursa-com.github.io/charts/microservice --set "image_tag=$image_tag"
```
and if you are using the chart as a dependency:
```
helm install <release-name> <parent_chart> --set "microservice.image_tag=$image_tag"
```

### GCPBackendPolicy (opt-in)

Set `backendPolicy.enabled: true` to render a `networking.gke.io/v1` `GCPBackendPolicy` targeting the app's Service. It is off by default and only rendered when the Service exists (`service.internalPort` set, or `debug.enabled` is true with `debug.port` set). Supported values: `securityPolicy` (Cloud Armor policy name), `timeoutSec`, `drainingTimeoutSec` (connection draining), `loggingEnabled` (default `true`) and `name` (default `<release name>-backend-config`). GKE allows only one GCPBackendPolicy per Service, so an app enabling this must not also ship its own policy for the same Service. See `values.yaml`.

### Internal Service for a second Gateway (opt-in)

GKE will not attach a Cloud Armor policy (`GCPBackendPolicy.securityPolicy`) to a Service that is a backend of both a regional internal gateway (`gke-l7-rilb`) and the global external gateway; each GatewayClass needs its own Service. Set `internalService.enabled: true` (requires `service.internalPort`, the render fails otherwise) to render a second Service `<appname>-internal` (override with `internalService.name`) with the same selector as the main Service and only the main app port (no debug port), plus:

- a `HealthCheckPolicy` (`internalService.healthCheck.enabled`, default `true`) targeting it, with `requestPath` from `internalService.healthCheck.requestPath`, else `api_gateway.health_endpoint` (the render fails if both are empty). It is not gated on `api_gateway.expose`.
- a `GCPBackendPolicy` (`internalService.backendPolicy.enabled`, default `true`, name `<internal Service name>-backend-config`). `timeoutSec`, `drainingTimeoutSec` and `loggingEnabled` inherit from `backendPolicy.*` when left `null`; any other value, including `0` or `false`, overrides. Note that an explicit `timeoutSec: 0` overrides rather than inherits, and the field is then omitted from the rendered policy, so GKE's default (30s) applies. `securityPolicy` is never inherited or set: it belongs on the main (public) Service only.

The chart does not route to the internal Service. The consumer must point its regional HTTPRoute `backendRef` at `<appname>-internal`. Rollout order: (1) enable `internalService` and let its NEG go healthy, (2) repoint the internal route at it, (3) set `backendPolicy.securityPolicy` on the main Service.

### AlloyDB Auth Proxy sidecar (opt-in)

Set `alloydbAuthProxy.enabled: true` and `alloydbAuthProxy.instanceUri` (`projects/PROJECT/locations/REGION/clusters/CLUSTER/instances/INSTANCE`) to run Google's [AlloyDB Auth Proxy](https://github.com/GoogleCloudPlatform/alloydb-auth-proxy) next to the app, listening on `127.0.0.1:<port>` (default `5432`). It is off by default, and the render fails if it is enabled for either Deployment while `instanceUri` is empty.

- **Native sidecar.** The proxy is rendered as the first `initContainers` entry with `restartPolicy: Always`, which needs Kubernetes 1.29+ (prod GKE runs 1.33; the chart does not check the version at render time). The kubelet starts any `init_container` and the app container only after the proxy's `startupProbe` (`/startup`) passes, and restarts the proxy on its own if it exits or fails its `livenessProbe` (`/liveness`). `/startup` passes once the proxy's listener is up; it does not wait for a connection to the instance, so an unreachable instance does not hold the app back.
- **No readinessProbe, on purpose.** A native sidecar's readiness counts toward the pod's, so a proxy readiness probe would take API pods out of their Service whenever the proxy reported not-ready. The upstream help says its `/readiness` also fails while an instance is unreachable, which would mean API pods dropping out whenever the database is down. The proxy's health is covered by the startup and liveness probes and by its restarts.
- **Port wiring.** The app container of each Deployment running the proxy gets `REPORTING_AUTH_PROXY_PORT` set to `alloydbAuthProxy.port`, so the two cannot drift. The render fails if `parameters` (or `worker.parameters`, for the worker) also sets `REPORTING_AUTH_PROXY_PORT`. The health server listens on `alloydbAuthProxy.healthPort` (default `9090`) on all pod addresses so kubelet probes reach it; neither port may collide with a port the app listens on, since the containers share the pod's network.
- **Worker-only opt-in.** The worker inherits `alloydbAuthProxy.enabled`. `worker.alloydbAuthProxy.enabled` overrides only that flag, for the worker: `true` turns it on for the worker alone, and an explicit `false` turns it off for the worker while the primary keeps it. All other settings come from the top-level block.

  ```yaml
  alloydbAuthProxy:
    instanceUri: projects/PROJECT/locations/REGION/clusters/CLUSTER/instances/INSTANCE
  worker:
    enabled: true
    alloydbAuthProxy:
      enabled: true
  ```
- **IAM.** The proxy authenticates as the pod's service account through Workload Identity. That GSA needs `roles/alloydb.client` and `roles/serviceusage.serviceUsageConsumer` in the project holding the cluster. Set `publicIp: true` only to connect over the instance's public IP (adds `--public-ip`); private IP is the default.
- **Resources.** `alloydbAuthProxy.resources` (default requests `50m` CPU / `64Mi`, memory limit `256Mi`, no CPU limit) is added to the pod's total requests.

The migration Job and linked services never get the proxy.

### Resource requests and limits

This chart allows setting min/max resources for all containers inside the chart deployment. Setting requests is essential for production workloads and these should be adapted to your specific use case.

To make this process easier, the chart contains the default values for a small application, and the scaling configuration. Ideally, never set the minimum of replicas to something lower than 2, unless for a specific need. This way we can have the app always available even during cluster operations. Find more information on container resource management in the [official Kubernetes documentation](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/).
