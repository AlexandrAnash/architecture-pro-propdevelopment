#!/bin/bash
set -e

for ns in sales tenant finance data; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-viewer
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "services", "endpoints", "configmaps", "persistentvolumeclaims",
              "persistentvolumes", "namespaces", "nodes", "events", "serviceaccounts",
              "resourcequotas", "limitranges", "replicationcontrollers"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps", "batch", "autoscaling", "networking.k8s.io", "policy", "storage.k8s.io"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-domain-developer
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "persistentvolumeclaims", "serviceaccounts"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/log", "events", "endpoints"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/exec", "pods/portforward"]
  verbs: ["create"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["create", "update", "patch"]
- apiGroups: ["apps", "batch", "autoscaling"]
  resources: ["*"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-cluster-operator
rules:
- apiGroups: [""]
  resources: ["namespaces", "nodes", "persistentvolumes", "resourcequotas", "limitranges",
              "pods", "pods/log", "pods/exec", "services", "endpoints", "configmaps",
              "persistentvolumeclaims", "events", "serviceaccounts"]
  verbs: ["*"]
- apiGroups: ["apps", "batch", "autoscaling", "policy", "networking.k8s.io", "storage.k8s.io",
              "apiextensions.k8s.io", "admissionregistration.k8s.io", "scheduling.k8s.io"]
  resources: ["*"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-secrets-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-rbac-admin
rules:
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs: ["*"]
EOF

kubectl get clusterroles | grep propdev
