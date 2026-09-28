# Задание 6. Аудит

## Как запустить

audit-policy кладём туда, откуда minikube скопирует её на ноду

```shell
mkdir -p ~/.minikube/files/etc/ssl/certs
cp audit-policy.yaml ~/.minikube/files/etc/ssl/certs/audit-policy.yaml

minikube start \
  --extra-config=apiserver.audit-policy-file=/etc/ssl/certs/audit-policy.yaml \
  --extra-config=apiserver.audit-log-path=-
```

```shell
bash simulate-incident.sh
kubectl logs -n kube-system kube-apiserver-minikube | grep '^{"kind":"Event"' > audit.log
python3 filter-audit.py audit.log > audit-extract.json
```

Отчёт — [analysis.md](analysis.md)
