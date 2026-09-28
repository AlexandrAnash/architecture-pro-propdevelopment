#!/bin/bash
# Небезопасные манифесты должны отклоняться, безопасные — проходить.
cd "$(dirname "$0")/.."
fail=0

for f in insecure-manifests/*.yaml; do
  if out=$(kubectl apply --dry-run=server -f "$f" 2>&1); then
    echo "FAIL  $f прошёл, а не должен"; fail=1
  else
    echo "OK    $f отклонён: $(echo "$out" | head -1 | sed "s/.*forbidden: //" | cut -c1-160)"
  fi
done

for f in secure-manifests/*.yaml; do
  if out=$(kubectl apply -f "$f" 2>&1); then
    echo "OK    $f: $out"
  else
    echo "FAIL  $f: $out"; fail=1
  fi
done

kubectl wait -n audit-zone --for=condition=Ready pod --all --timeout=120s
exit $fail
