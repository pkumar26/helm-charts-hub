# Technical Plan: Controller Charts

## 1. Architecture

Both controller charts follow the same pattern:
- **common-lib dependency** for metadata helpers (labels, annotations, fullname, selectorLabels, serviceaccount)
- **Custom deployment template** (controllers need multi-port, custom args, RBAC — too different from common-lib.deployment)
- **Custom service template** (controllers need LoadBalancer with multiple named ports)
- **Controller-specific resources** (IngressClass, ClusterRole, ClusterRoleBinding, ConfigMap)

## 2. Traefik Controller Chart

### 2.1 Structure
```
charts/traefik-controller/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   ├── clusterrole.yaml
│   ├── clusterrolebinding.yaml
│   ├── ingressclass.yaml
│   ├── configmap.yaml
│   ├── gateway-class.yaml      # Gated: gatewayApi.enabled
│   ├── gateway.yaml             # Gated: gatewayApi.enabled
│   └── NOTES.txt
├── ci/
│   ├── test-values.yaml
│   └── test-gateway-values.yaml
└── README.md
```

### 2.2 Key Design Decisions
- Deployment uses Traefik CLI args for provider configuration
- Service exposes ports: web (80), websecure (443)
- RBAC: ClusterRole with permissions for Ingress, Services, Endpoints, Secrets, and optionally Gateway API resources
- IngressClass: `traefik` (default)
- Gateway API: GatewayClass + Gateway gated behind `gatewayApi.enabled`

### 2.3 Values Schema
See 001-foundational-spec/plan.md §5.2

## 3. NGINX Controller Chart

### 3.1 Structure
```
charts/nginx-controller/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── serviceaccount.yaml
│   ├── clusterrole.yaml
│   ├── clusterrolebinding.yaml
│   ├── ingressclass.yaml
│   ├── configmap.yaml
│   └── NOTES.txt
├── ci/
│   └── test-values.yaml
└── README.md
```

### 3.2 Key Design Decisions
- Based on `ingress-nginx` project (Ingress-only controller)
- Controller ConfigMap for NGINX configuration overrides
- IngressClass: `nginx` (default)
- Gateway API: Placeholder values only (roadmap — requires nginx-gateway-fabric)

### 3.3 Values Schema
See 001-foundational-spec/plan.md §6.3

## 4. common-lib Usage

Both charts use common-lib for:
- `common-lib.labels` and `common-lib.selectorLabels`: Consistent metadata
- `common-lib.annotations`: Consistent annotations
- `common-lib.fullname` and `common-lib.chart`: Naming
- `common-lib.serviceaccount`: ServiceAccount creation

Both charts use **custom** templates for:
- Deployment (multi-port, custom args, controller-specific containers)
- Service (LoadBalancer, multiple named ports)
- RBAC (ClusterRole, ClusterRoleBinding — cluster-scoped, controller-specific)
- IngressClass (controller-specific)
- ConfigMap (controller-specific configuration)
