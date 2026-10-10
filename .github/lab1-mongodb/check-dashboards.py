#!/usr/bin/env python3
"""Проверка дашбордов Grafana.

  check-dashboards.py FILE...                 структура: JSON, uid, источник данных, выражения
  check-dashboards.py --vm URL FILE...        плюс каждый запрос выполняется в VictoriaMetrics
                                              и должен вернуть данные

Панели про replica set в дашборде 12079 на одиночном mongod пустые: они в EXPECTED_EMPTY.
"""

import json
import sys
import urllib.parse
import urllib.request

DATASOURCES = [
    {"type": "prometheus", "uid": "victoriametrics"},
    {"type": "prometheus", "uid": "${datasource}"},
]
BUILTIN = {"type": "datasource", "uid": "grafana"}
# Нет данных на standalone mongod или нет метрики в mongodb_exporter 0.53.
EXPECTED_EMPTY = {
    "mongodb_mongod_replset_",
    "mongodb_op_counters_repl_total",
    "mongodb_network_bytes_total",
}
# Переменные шаблонов Grafana -> значения для запроса к VictoriaMetrics.
VARS = {
    "$env": ".*",
    "$job": ".*",
    "$instance": ".*",
    "$interval": "5m",
    "$__rate_interval": "1m",
    "$__interval": "1m",
}


def targets(dash):
    for panel in dash["panels"]:
        for target in panel.get("targets", []):
            if target.get("expr"):
                yield panel, target


def check_structure(path, dash, uids):
    errors = []
    if dash.get("uid") in uids:
        errors.append(f"duplicate uid {dash.get('uid')}")
    uids.add(dash.get("uid"))
    text = json.dumps(dash)
    if "${DS_" in text:
        errors.append("datasource placeholder ${DS_...} left in file")
    for panel, target in targets(dash):
        for ds in (panel.get("datasource"), target.get("datasource")):
            if ds not in [None, BUILTIN, "-- Grafana --", *DATASOURCES]:
                errors.append(f"panel '{panel['title']}': datasource {ds}")
    return [f"{path}: {e}" for e in errors]


def check_queries(vm, path, dash):
    errors = []
    for panel, target in targets(dash):
        expr = target["expr"]
        for var, value in VARS.items():
            expr = expr.replace(var, value)
        url = vm + "/api/v1/query?" + urllib.parse.urlencode({"query": expr})
        try:
            with urllib.request.urlopen(url) as r:
                result = json.load(r)["data"]["result"]
        except urllib.error.HTTPError as e:
            errors.append(
                f"panel '{panel['title']}': bad query {expr}: {e.read()[:200]}"
            )
            continue
        expected_empty = any(m in expr for m in EXPECTED_EMPTY)
        if not result and not expected_empty:
            errors.append(f"panel '{panel['title']}': no data for {expr}")
    return [f"{path}: {e}" for e in errors]


def main():
    args = sys.argv[1:]
    vm = None
    if args[:1] == ["--vm"]:
        vm, args = args[1], args[2:]
    errors, uids, queries = [], set(), 0
    for path in args:
        with open(path) as f:
            dash = json.load(f)
        errors += check_structure(path, dash, uids)
        queries += sum(1 for _ in targets(dash))
        if vm:
            errors += check_queries(vm, path, dash)
    for e in errors:
        print("ERROR", e)
    mode = "structure + data" if vm else "structure"
    print(f"{len(args)} dashboards, {queries} queries, {mode}: {len(errors)} errors")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
