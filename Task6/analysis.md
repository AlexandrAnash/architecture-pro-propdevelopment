# Отчет по результатам анализа Kubernetes Audit Log

В [audit.log](audit.log) оставил только окно запуска `simulate-incident.sh` (18:16:49 и дальше), выжимка — [audit-extract.json](audit-extract.json), скрипт — [filter-audit.py](filter-audit.py).

```shell
python3 filter-audit.py audit.log > audit-extract.json
```

## Подозрительные события

1. Доступ к секретам:
   - Кто: `minikube-user` от имени `system:serviceaccount:secure-ops:monitoring` (impersonation, `--as`)
   - Где: `kube-system`, `list secrets`
   - Почему подозрительно: сервисный аккаунт мониторинга лезет в секреты системного namespace. Запрос получил **403** — прав у monitoring нет, т.е. на этом шаге атака не удалась.
     Перед этим `minikube-user` сам сделал `list secrets` в kube-system (200) — это подстановка `$(kubectl get secrets ... | grep default-token)` из скрипта, искал токен. `default-token-*` в 1.24+ уже не создаются, поэтому имя пустое и kubectl сделал list вместо get.
     Проверка из задания `jq 'select(.objectRef.resource=="secrets" and .verb=="get")'` из-за этого ничего не находит — искать надо и `list`.

2. Привилегированные поды:
   - Кто: `minikube-user` (группа `system:masters`)
   - Комментарий: `privileged-pod` в `secure-ops`, `privileged: true`, 201 — создан. Привилегированный контейнер = root на ноде (доступ к устройствам, можно смонтировать диск хоста и выйти из контейнера). В namespace нет PodSecurity, поэтому ничего не остановило. Рядом `attacker-pod` — обычный, но название говорит само за себя.

3. Использование kubectl exec в чужом поде:
   - Кто: `minikube-user`
   - Что делал: exec в `kube-system/coredns-...`, команда `cat /etc/resolv.conf`. В образе coredns нет `cat`, команда упала (exit 127), но сессия exec открылась (101 Switching Protocols) — доступ был.
     
4. Создание RoleBinding с правами cluster-admin:
   - Кто: `minikube-user`
   - К чему привело: `escalate-binding` в `secure-ops` → ClusterRole `cluster-admin` для SA `monitoring`. Проверил после: `kubectl auth can-i '*' '*' -n secure-ops --as=system:serviceaccount:secure-ops:monitoring` → **yes**. Т.е. любой под с этим SA полный админ в namespace (секреты, под...). Н

5. Удаление audit-policy.yaml:
   - Кто: попытка от `admin` (`--as=admin`)
   - Возможные последствия: не обнаружил

## Кто всё это делал

Все действия — `minikube-user`, он в `system:masters`. Это не "злоумышленник", а общий админский сертификат minikube. По аудиту нельзя сказать, какой человек за ним стоит — это и есть главная проблема.

## Вывод

Атака из скрипта удалась на 2 из 5 шагов: привилегированный под и cluster-admin для SA. Корень — общий админский доступ `system:masters` без персональных учеток и отсутствие admission-политик (PodSecurity / Gatekeeper). Лечится персональными ролями (Task4) и алертами на события из `filter-audit.py`.
