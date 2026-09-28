#!/bin/bash
set -e

CA_DIR="${CA_DIR:-$HOME/.minikube}"
OUT_DIR="$(dirname "$0")/certs"
CLUSTER=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
mkdir -p "$OUT_DIR"

# user:group
USERS="
anna.viewer:propdev:viewers
petr.sales:propdev:sales-dev
oleg.platform:propdev:platform
irina.security:propdev:security
"

for entry in $USERS; do
  user="${entry%%:*}"
  group="${entry#*:}"
  echo "== $user ($group)"

  openssl genrsa -out "$OUT_DIR/$user.key" 2048 2>/dev/null
  openssl req -new -key "$OUT_DIR/$user.key" -out "$OUT_DIR/$user.csr" -subj "/CN=$user/O=$group"
  openssl x509 -req -in "$OUT_DIR/$user.csr" -CA "$CA_DIR/ca.crt" -CAkey "$CA_DIR/ca.key" \
    -CAcreateserial -out "$OUT_DIR/$user.crt" -days 90 2>/dev/null

  kubectl config set-credentials "$user" \
    --client-certificate="$OUT_DIR/$user.crt" --client-key="$OUT_DIR/$user.key" --embed-certs=true
  kubectl config set-context "$user" --cluster="$CLUSTER" --user="$user"
done

echo "Готово. Можно вызвать и проверить: kubectl --context=anna.viewer get pods -A"
