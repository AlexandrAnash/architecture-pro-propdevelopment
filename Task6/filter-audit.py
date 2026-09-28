#!/usr/bin/env python3
"""Выбирает из audit.log подозрительные события.

python3 filter-audit.py audit.log > audit-extract.json
"""
import json
import sys

SYSTEM_PREFIXES = ("system:kube-", "system:node:", "system:apiserver", "system:serviceaccount:kube-system:")
BOOTSTRAP_USERS = ("kubernetes-admin", "kubernetes-super-admin", "minikube")


def is_system(user):
    return user in BOOTSTRAP_USERS or user.startswith(SYSTEM_PREFIXES)


def actor(e):
    user = e["user"]["username"]
    imp = e.get("impersonatedUser")
    return f"{user} as {imp['username']}" if imp else user


def check(e):
    """Возвращает причину, если событие подозрительное, иначе None."""
    ref = e.get("objectRef", {})
    res, sub, verb = ref.get("resource"), ref.get("subresource"), e.get("verb")
    user = e["user"]["username"]
    if is_system(user):
        return None

    if "audit" in (e.get("requestURI", "") + str(ref.get("name"))):
        return "изменение audit-policy"

    if res == "secrets" and verb in ("get", "list", "watch"):
        if e.get("impersonatedUser") or user.startswith("system:serviceaccount:"):
            return "доступ к secrets от сервисного аккаунта"
        if ref.get("namespace") == "kube-system":
            return "доступ к secrets в kube-system"

    if res == "pods" and sub == "exec" and verb in ("create", "get"):
        return "kubectl exec в под"

    if res == "pods" and verb == "create" and not sub:
        spec = (e.get("requestObject") or {}).get("spec", {})
        for c in spec.get("containers", []) + spec.get("initContainers", []):
            if (c.get("securityContext") or {}).get("privileged"):
                return "создание привилегированного пода"
        if spec.get("hostNetwork") or spec.get("hostPID"):
            return "под с доступом к хосту"

    if res in ("rolebindings", "clusterrolebindings") and verb in ("create", "update", "patch"):
        body = e.get("requestObject")
        if not body:
            return "создание/изменение привязки роли (roleRef не залогирован)"
        role = (body.get("roleRef") or {}).get("name")
        if role in ("cluster-admin", "admin", "edit"):
            return f"выдача роли {role}"

    imp = (e.get("impersonatedUser") or {}).get("username", "")
    if imp.startswith("system:serviceaccount:") and res != "selfsubjectaccessreviews" and res:
        return "действие от имени сервисного аккаунта (--as)"

    return None


def main(path):
    found = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line.startswith("{"):
                continue
            e = json.loads(line)
            if e.get("stage") != "ResponseComplete":
                continue
            reason = check(e)
            if not reason:
                continue
            ref = e.get("objectRef", {})
            found.append({
                "reason": reason,
                "time": e.get("requestReceivedTimestamp"),
                "who": actor(e),
                "groups": e["user"].get("groups"),
                "verb": e.get("verb"),
                "resource": "/".join(x for x in (ref.get("resource"), ref.get("subresource")) if x),
                "namespace": ref.get("namespace"),
                "name": ref.get("name"),
                "uri": e.get("requestURI"),
                "code": (e.get("responseStatus") or {}).get("code"),
                "decision": e.get("annotations", {}).get("authorization.k8s.io/decision"),
                "auditID": e.get("auditID"),
            })
    json.dump(found, sys.stdout, ensure_ascii=False, indent=2)
    print()
    print(f"найдено: {len(found)}", file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "audit.log")
