# Requirements Checklist: kgateway Controller Chart

**Feature Branch**: `004-kgateway-chart`

Maps each acceptance criterion from spec.md §4 to a verification step and task.

---

## Acceptance Criteria Verification

| # | Criterion | Verification Command | Task(s) | Status |
|---|-----------|---------------------|---------|--------|
| AC-1 | `helm lint` passes with zero errors | `helm lint charts/kgateway-controller` | T013, T027 | [ ] |
| AC-2 | `helm template` renders Deployment, Service, ServiceAccount, ClusterRole, ClusterRoleBinding | `helm template kgw charts/kgateway-controller \| grep 'kind:'` | T013 | [ ] |
| AC-3 | GatewayClass only rendered when `gatewayApi.createGatewayClass: true` | `helm template kgw charts/kgateway-controller --set gatewayApi.createGatewayClass=true \| grep GatewayClass` and verify absent by default | T015 | [ ] |
| AC-4 | All resources carry 6 base labels + 2 base annotations | `helm template kgw charts/kgateway-controller \| grep -A10 'labels:'` — check all 6 labels present | T004, T009 | [ ] |
| AC-5 | GatewayClass references controller name `kgateway.dev/kgateway` | `helm template kgw charts/kgateway-controller --set gatewayApi.createGatewayClass=true \| grep controllerName` | T014 | [ ] |
| AC-6 | RBAC grants minimum required permissions | Inspect ClusterRole rules in `helm template` output for all required apiGroups | T007 | [ ] |
| AC-7 | Service type ClusterIP by default | `helm template kgw charts/kgateway-controller \| grep -A5 'kind: Service' \| grep type` | T010 | [ ] |
| AC-8 | HPA only rendered when `autoscaling.enabled: true` | `helm template kgw charts/kgateway-controller --set autoscaling.enabled=true \| grep HorizontalPodAutoscaler` and verify absent by default | T017 | [ ] |
| AC-9 | PDB only rendered when `podDisruptionBudget.enabled: true` | `helm template kgw charts/kgateway-controller --set podDisruptionBudget.enabled=true \| grep PodDisruptionBudget` and verify absent by default | T020 | [ ] |
| AC-10 | VPA only rendered when `verticalPodAutoscaler.enabled: true` | `helm template kgw charts/kgateway-controller --set verticalPodAutoscaler.enabled=true \| grep VerticalPodAutoscaler` and verify absent by default | T020 | [ ] |
| AC-11 | CI test values pass `helm lint` and `helm template` | `helm lint charts/kgateway-controller -f charts/kgateway-controller/ci/test-values.yaml` and `…/ci/test-full-values.yaml` | T027 | [ ] |
| AC-12 | Environment overlays exist for dev, staging, production | `ls environments/*/kgateway-controller.values.yaml` | T022, T023, T024 | [ ] |
| AC-13 | README includes all 7 required sections per constitution §9.2 | Manual review: Overview, Prerequisites, Installation, Configuration, Examples, Upgrade Notes, Troubleshooting | T026 | [ ] |

---

## Functional Requirements Traceability

| Requirement | Description | Task(s) | Verification |
|-------------|-------------|---------|--------------|
| FR-1 | Controller Deployment | T009 | AC-2, AC-4 |
| FR-2 | GatewayClass (optional) | T014 | AC-3, AC-5 |
| FR-3 | RBAC | T007, T008 | AC-6 |
| FR-4 | Service | T010 | AC-7 |
| FR-5 | ServiceAccount | T006 | AC-2 |
| FR-6 | HPA | T016 | AC-8 |
| FR-7 | PDB | T018 | AC-9 |
| FR-8 | VPA | T019 | AC-10 |
