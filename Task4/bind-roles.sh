#!/bin/bash
# Привязка групп к ролям. Привязываем группы, а не пользователей —
# при приходе нового сотрудника достаточно выпустить сертификат с нужным O.
set -e

bind_cluster() { # имя роль группа
  kubectl create clusterrolebinding "$1" --clusterrole="$2" --group="$3" \
    --dry-run=client -o yaml | kubectl apply -f -
}

bind_ns() { # namespace роль группа
  kubectl create rolebinding "$2-$1" -n "$1" --clusterrole="$2" --group="$3" \
    --dry-run=client -o yaml | kubectl apply -f -
}

bind_cluster propdev-viewers          propdev-viewer           propdev:viewers
bind_cluster propdev-platform         propdev-cluster-operator propdev:platform
bind_cluster propdev-security-secrets propdev-secrets-reader   propdev:security
bind_cluster propdev-security-rbac    propdev-rbac-admin       propdev:security
bind_cluster propdev-break-glass      cluster-admin            propdev:break-glass

for ns in sales tenant finance data; do
  bind_ns "$ns" propdev-domain-developer "propdev:$ns-dev"
done

echo
echo "== Проверка"
check() { # пользователь группа действие... ожидание
  local expect="${@: -1}"
  local res
  res=$(kubectl auth can-i "${@:3:$#-3}" --as="$1" --as-group="$2" 2>/dev/null || true)
  printf '%-16s %-40s %-4s (ожидали %s)\n' "$1" "${*:3:$#-3}" "$res" "$expect"
}

check anna.viewer    propdev:viewers   get pods -n sales             yes
check anna.viewer    propdev:viewers   get secrets -n sales          no
check anna.viewer    propdev:viewers   delete pods -n sales          no
check petr.sales     propdev:sales-dev create deployments -n sales   yes
check petr.sales     propdev:sales-dev get secrets -n sales          no
check petr.sales     propdev:sales-dev create deployments -n finance no
check oleg.platform  propdev:platform  create namespaces             yes
check oleg.platform  propdev:platform  get secrets -n finance        no
check oleg.platform  propdev:platform  create rolebindings -n sales  no
check irina.security propdev:security  get secrets -n finance        yes
check irina.security propdev:security  delete pods -n finance        no
