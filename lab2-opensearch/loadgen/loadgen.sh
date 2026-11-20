#!/bin/sh
# Send requests to nginx in a loop. Half of them hit a missing page (status 404).
# BATCH is the number of requests of each kind per round, PAUSE is the sleep between rounds.
set -eu

BATCH=${BATCH:-5}
PAUSE=${PAUSE:-1}
URL=${URL:-http://nginx}

while true; do
  curl -s -A lab2-loadgen --parallel --parallel-max 10 \
    "$URL/?n=[1-$BATCH]" "$URL/missing-[1-$BATCH]" > /dev/null || true
  sleep "$PAUSE"
done
