# Задание 7. PodSecurity + OPA Gatekeeper

## Как запустить

```shell
minikube start

# Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.23.1/deploy/gatekeeper.yaml
kubectl wait -n gatekeeper-system --for=condition=Ready pod --all --timeout=300s

# namespace с PodSecurity restricted
kubectl apply -f 01-create-namespace.yaml

# сначала шаблоны, потом (секунд через 10-15, пока создадутся CRD) ограничения
kubectl apply -f gatekeeper/constraint-templates/
kubectl apply -f gatekeeper/constraints/
```

## Проверка

```shell
./verify/verify-admission.sh    # insecure отклоняются, secure создаются
./verify/validate-security.sh   # PodSecurity и Gatekeeper включены, Gatekeeper работает и без PodSecurity
```

Что вышло у меня:

```
OK    insecure-manifests/01-privileged-pod.yaml отклонён: violates PodSecurity "restricted:latest": privileged ...
OK    insecure-manifests/02-hostpath-pod.yaml отклонён: violates PodSecurity "restricted:latest": ... unrestricted volume types ...
OK    insecure-manifests/03-root-user-pod.yaml отклонён: violates PodSecurity "restricted:latest": ... runAsUser=0 ...
OK    secure-manifests/01-secure.yaml: pod/pod-privileged-fixed created
OK    secure-manifests/02-secure.yaml: pod/pod-hostpath-fixed created
OK    secure-manifests/03-secure.yaml: pod/pod-root-fixed created

== Gatekeeper без PodSecurity (ns gatekeeper-check)
-- insecure-manifests/01-privileged-pod.yaml
[deny-privileged] privileged контейнер запрещён: nginx
[require-nonroot-readonly] нужен readOnlyRootFilesystem: true: nginx
[require-nonroot-readonly] нужен runAsNonRoot: true: nginx
-- insecure-manifests/02-hostpath-pod.yaml
[deny-hostpath] hostPath запрещён: volume host-etc (/etc)
...
-- insecure-manifests/03-root-user-pod.yaml
[require-nonroot-readonly] запуск от UID 0 запрещён: nginx
...
```
