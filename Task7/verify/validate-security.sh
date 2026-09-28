#!/bin/bash
# Проверяет, что PodSecurity и Gatekeeper включены и каждый работает сам по себе.
cd "$(dirname "$0")/.."

echo "== PodSecurity на audit-zone"
kubectl get ns audit-zone -o jsonpath='{.metadata.labels}' | tr ',' '\n' | grep pod-security

echo
echo "== Gatekeeper"
kubectl get pods -n gatekeeper-system
kubectl get constrainttemplates
kubectl get constraints

echo
echo "== Gatekeeper без PodSecurity (ns gatekeeper-check)"
kubectl create ns gatekeeper-check --dry-run=client -o yaml | kubectl apply -f - >/dev/null
for f in insecure-manifests/*.yaml; do
  echo "-- $f"
  sed 's/namespace: audit-zone/namespace: gatekeeper-check/' "$f" \
    | kubectl apply --dry-run=server -f - 2>&1 | grep -o '\[[a-z-]*\].*' || echo "FAIL: не отклонён Gatekeeper'ом"
done

echo
echo "== Нарушения, найденные аудитом Gatekeeper (существующие объекты)"
for c in $(kubectl get constraints -o name); do
  echo "$c: $(kubectl get "$c" -o jsonpath='{.status.totalViolations}')"
done
