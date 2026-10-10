#!/usr/bin/env python3
"""Значения выбранных метрик из VictoriaMetrics.

  vmquery.py METRICS.json                сейчас, окно 5m
  vmquery.py METRICS.json START END      окно "до" = [START-(END-START), START], "во время" = [START, END]

METRICS.json: [{"name": ..., "expr": ...}], в expr $w = длина окна.
"""

import json
import math
import sys
import urllib.parse
import urllib.request

VM = "http://127.0.0.1:8428/api/v1/query"


def query(expr, at=None):
    params = {"query": expr}
    if at is not None:
        params["time"] = str(at)
    with urllib.request.urlopen(VM + "?" + urllib.parse.urlencode(params)) as r:
        result = json.load(r)["data"]["result"]
    return float(result[0]["value"][1]) if result else math.nan


def fmt(v):
    return "no data" if math.isnan(v) else f"{v:.2f}".rstrip("0").rstrip(".")


with open(sys.argv[1]) as f:
    metrics = json.load(f)
width = max(len(m["name"]) for m in metrics)
if len(sys.argv) == 2:
    for m in metrics:
        print(f"{m['name']:<{width}} = {fmt(query(m['expr'].replace('$w', '5m')))}")
else:
    start, end = int(sys.argv[2]), int(sys.argv[3])
    w = f"{end - start}s"
    print(f"{'metric':<{width}} | before | during")
    for m in metrics:
        expr = m["expr"].replace("$w", w)
        print(
            f"{m['name']:<{width}} | {fmt(query(expr, start))} | {fmt(query(expr, end))}"
        )
