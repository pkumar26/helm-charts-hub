# Requirements Checklist: Controller Charts

## Core Requirements
- [X] Traefik controller chart scaffolded with common-lib dependency
- [X] NGINX controller chart scaffolded with common-lib dependency
- [X] Both charts use common-lib for labels, annotations, naming
- [X] Both charts have custom Deployment templates (multi-port, controller args)
- [X] Both charts have custom Service templates (LoadBalancer, named ports)
- [X] Both charts have RBAC (ClusterRole + ClusterRoleBinding)
- [X] Both charts have IngressClass resources
- [X] Traefik chart supports Gateway API mode (gated)
- [X] NGINX chart has controller ConfigMap for config overrides

## Quality Requirements
- [X] helm lint passes for both charts
- [X] helm template renders valid YAML for both charts
- [X] All resources carry 6 base labels + 2 base annotations
- [X] CI test values provided for both charts
- [X] README with required sections for both charts
- [X] Environment overlays provided
- [X] Root CHARTS.md updated
