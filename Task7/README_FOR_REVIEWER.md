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

## Пояснения

- В audit-zone небезопасный под отбивает PodSecurity раньше Gatekeeper'а, поэтому по одному audit-zone не понять, работает ли Gatekeeper. Для этого ограничения матчат ещё namespace `gatekeeper-check` без меток PodSecurity, `validate-security.sh` проверяет в нём.
- Правил 4, а шаблонов по структуре из задания 3 — `readOnlyRootFilesystem` положил в `runasnonroot.yaml` вместе с runAsNonRoot / UID 0.
- Secure-манифесты на `nginxinc/nginx-unprivileged:alpine`: обычный nginx стартует от root и пишет в `/var/cache/nginx`, с `runAsNonRoot` + `readOnlyRootFilesystem` не поднимется. Unprivileged работает от UID 101 на порту 8080, пишет только в `/tmp` (emptyDir).
- `audit-policy.yaml` — пишет создание подов в audit-zone с телом запроса (видно securityContext) и любые изменения namespace'ов и политик Gatekeeper. Подключается как в Task6: `--extra-config=apiserver.audit-policy-file=...`.

Проверял на minikube v1.35.1 (k8s 1.35), Gatekeeper v3.23.1.
