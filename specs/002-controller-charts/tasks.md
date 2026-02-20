# Tasks: Controller Charts — Traefik & NGINX

## Phase 1: Chart Scaffolding
- [ ] T001: Create `charts/traefik-controller/Chart.yaml` with common-lib dependency
- [ ] T002: Create `charts/nginx-controller/Chart.yaml` with common-lib dependency
- [ ] T003: Run `helm dependency build` for both charts

## Phase 2: Traefik Controller — Values & Helpers
- [ ] T004: Create `charts/traefik-controller/values.yaml` with full schema
- [ ] T005: Create `charts/traefik-controller/templates/_helpers.tpl` with name/fullname overrides

## Phase 3: Traefik Controller — Core Templates
- [ ] T006: Create `charts/traefik-controller/templates/deployment.yaml` with multi-port, Traefik args
- [ ] T007: Create `charts/traefik-controller/templates/service.yaml` with LoadBalancer, web/websecure ports
- [ ] T008: Create `charts/traefik-controller/templates/serviceaccount.yaml` using common-lib helper
- [ ] T009: Create `charts/traefik-controller/templates/clusterrole.yaml` with Ingress/Gateway API RBAC
- [ ] T010: Create `charts/traefik-controller/templates/clusterrolebinding.yaml`
- [ ] T011: Create `charts/traefik-controller/templates/ingressclass.yaml`
- [ ] T012: Create `charts/traefik-controller/templates/configmap.yaml` for static configuration

## Phase 4: Traefik Controller — Gateway API Templates
- [ ] T013: Create `charts/traefik-controller/templates/gateway-class.yaml` gated on `gatewayApi.enabled`
- [ ] T014: Create `charts/traefik-controller/templates/gateway.yaml` gated on `gatewayApi.enabled`

## Phase 5: Traefik Controller — Docs & CI
- [ ] T015: Create `charts/traefik-controller/templates/NOTES.txt`
- [ ] T016: Create `charts/traefik-controller/ci/test-values.yaml`
- [ ] T017: Create `charts/traefik-controller/ci/test-gateway-values.yaml`
- [ ] T018: Create `charts/traefik-controller/README.md`

## Phase 6: NGINX Controller — Values & Helpers
- [ ] T019: Create `charts/nginx-controller/values.yaml` with full schema
- [ ] T020: Create `charts/nginx-controller/templates/_helpers.tpl` with name/fullname overrides

## Phase 7: NGINX Controller — Core Templates
- [ ] T021: Create `charts/nginx-controller/templates/deployment.yaml` with NGINX controller args
- [ ] T022: Create `charts/nginx-controller/templates/service.yaml` with LoadBalancer, http/https ports
- [ ] T023: Create `charts/nginx-controller/templates/serviceaccount.yaml` using common-lib helper
- [ ] T024: Create `charts/nginx-controller/templates/clusterrole.yaml` with Ingress RBAC
- [ ] T025: Create `charts/nginx-controller/templates/clusterrolebinding.yaml`
- [ ] T026: Create `charts/nginx-controller/templates/ingressclass.yaml`
- [ ] T027: Create `charts/nginx-controller/templates/configmap.yaml` for NGINX configuration

## Phase 8: NGINX Controller — Docs & CI
- [ ] T028: Create `charts/nginx-controller/templates/NOTES.txt`
- [ ] T029: Create `charts/nginx-controller/ci/test-values.yaml`
- [ ] T030: Create `charts/nginx-controller/README.md`

## Phase 9: Integration & Validation
- [ ] T031: Update root `CHARTS.md` with both controller charts
- [ ] T032: Add environment overlays for controller charts
- [ ] T033: Run `helm lint` on both charts — zero errors
- [ ] T034: Run `helm template` on both charts — validate output
- [ ] T035: Validate Traefik Gateway API templates with gateway values
