#!/bin/sh
# Apply the component template, the index template and the ISM policy.
# The script is safe to run again: every step replaces the old object.
set -eu

URL=${URL:-https://hot1:9200}
CA=${CA:-/certs/root-ca.pem}
DIR=${DIR:-/lab}
: "${ADMIN_PASSWORD:?set it in .env}"

# call METHOD PATH [FILE]: print the HTTP code, the body goes to /tmp/body.
call() {
  method=$1 path=$2 file=${3:-}
  if [ -n "$file" ]; then
    curl -sS -o /tmp/body -w '%{http_code}' --cacert "$CA" -u "admin:$ADMIN_PASSWORD" \
      -H 'Content-Type: application/json' -X "$method" "$URL$path" --data-binary "@$file"
  else
    curl -sS -o /tmp/body -w '%{http_code}' --cacert "$CA" -u "admin:$ADMIN_PASSWORD" \
      -X "$method" "$URL$path"
  fi
}

# put PATH FILE: PUT a file and stop if the code is not 200 or 201.
put() {
  code=$(call PUT "$1" "$2")
  case $code in
    200 | 201) echo "PUT $1 -> $code" ;;
    *) echo "PUT $1 -> $code" >&2; cat /tmp/body >&2; echo >&2; exit 1 ;;
  esac
}

# Wait until the cluster answers with yellow or green.
i=0
until [ "$(call GET '/_cluster/health?wait_for_status=yellow&timeout=5s')" = 200 ]; do
  i=$((i + 1))
  if [ "$i" -ge 60 ]; then
    echo "cluster is not ready after 60 tries" >&2
    exit 1
  fi
  sleep 5
done

put /_component_template/logs-nginx-settings "$DIR/templates/logs-nginx-settings.json"
put /_index_template/logs-nginx "$DIR/templates/logs-nginx-template.json"

# ISM refuses to replace a policy unless the request has the current
# seq_no and primary_term. A new policy needs no parameters.
code=$(call GET /_plugins/_ism/policies/logs-nginx)
case $code in
  200)
    seq_no=$(sed -n 's/.*"_seq_no":\([0-9]*\).*/\1/p' /tmp/body)
    term=$(sed -n 's/.*"_primary_term":\([0-9]*\).*/\1/p' /tmp/body)
    put "/_plugins/_ism/policies/logs-nginx?if_seq_no=$seq_no&if_primary_term=$term" "$DIR/ism/logs-nginx-policy.json"
    ;;
  404) put /_plugins/_ism/policies/logs-nginx "$DIR/ism/logs-nginx-policy.json" ;;
  *) echo "GET policy -> $code" >&2; cat /tmp/body >&2; exit 1 ;;
esac
