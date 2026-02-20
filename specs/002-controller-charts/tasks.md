# Tasks: Controller Charts — Traefik & NGINX

## Phase 1: Chart Scaffolding
- [X] T001: Create `charts/traefik-controller/Chart.yaml` with common-lib dependency
- [X] T002: Create `charts/nginx-controller/Chart.yaml` with common-lib dependency
- [X] T003: Run `helm dependency build` for both charts

## Phase 2: Traefik Controller — Values & Helpers
- [X] T004: Create `charts/traefik-controller/values.yaml` with full schema
- [X] T005: Create `charts/traefik-controller/templates/_helpers.tpl` with name/fullname overrides

## Phase 3: Traefik Controller — Core Templates
- [X] T006: Create `charts/traefik-controller/templates/deployment.yaml` with multi-port, Traefik args
- [X] T007: Create `charts/traefik-controller/templates/service.yaml` with LoadBalancer, web/websecure ports
- [X] T008: Create `charts/traefik-controller/templates/serviceaccount.yaml` using common-lib helper
- [X] T009: Create `charts/traefik-controller/templates/clusterrole.yaml` with Ingress/Gateway API RBAC
- [X] T010: Create `charts/traefik-controller/templates/clusterrolebinding.yaml`
- [X] T011: Create `charts/traefik-controller/templates/ingressclass.yaml`
- [X] T012: Create `charts/traefik-controller/templates/configmap.yaml` for static configuration

## Phase 4: Traefik Controller — Gateway API Templates
- [X] T013: Create `charts/traefik-controller/templates/gateway-class.yaml` gated on `gatewayApi.enabled`
- [X] T014: Create `charts/traefik-controller/templates/gateway.yaml` gated on `gatewayApi.enabled`

## Phase 5: Traefik Controller — Docs & CI
- [X] T015: Create `charts/traefik-controller/templates/NOTES.txt`
- [X] T016: Create `charts/traefik-controller/ci/test-values.yaml`
- [X] T017: Create `charts/traefik-controller/ci/test-gateway-values.yaml`
- [X] T018: Create `charts/traefik-controller/README.md`

## Phase 6: NGINX Controller — Values & Helpers
- [X] T019: Create `charts/nginx-controller/values.yaml` with full schema
- [X] T020: Create `charts/nginx-controller/templates/_helpers.tpl` with name/fullname overrides

## Phase 7: NGINX Controller — Core Templates
- [X] T021: Create `charts/nginx-controller/templates/deployment.yaml` with NGINX controller args
- [X] T022: Create `charts/nginx-controller/templates/service.yaml` with LoadBalancer, http/https ports
- [X] T023: Create `charts/nginx-controller/templates/serviceaccount.yaml` using common-lib helper
- [X] T024: Create `charts/nginx-controller/templates/clusterrole.yaml` with Ingress RBAC
- [X] T025: Create `charts/nginx-controller/templates/clusterrolebinding.yaml`
- [X] T026: Create `charts/nginx-controller/templates/ingressclass.yaml`
- [X] T027: Create `charts/nginx-controller/templates/configmap.yaml` for NGINX configuration

## Phase 8: NGINX Controller — Docs & CI
- [X] T028: Create `charts/nginx-controller/templates/NOTES.txt`
- [X] T029: Create `charts/nginx-controller/ci/test-values.yaml`
- [X] T030: Create `charts/nginx-controller/README.md`

## Phase 9: Integration & Validation
- [X] T031: Update root `CHARTS.md` with both controller charts
- [X] T032: Add environment overlays for controller charts
- [X] T033: Run `helm lint` on both charts — zero errors
- [X] T034: Run `helm template` on both charts — validate output
- [X] T035: Validate Traefik Gateway API templates with gateway values
