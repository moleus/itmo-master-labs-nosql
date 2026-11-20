#!/bin/sh
# Make a lab CA and certificates for the OpenSearch nodes, the admin and Bento.
# The script does nothing if the CA is already in $OUT.
set -eu

OUT=${OUT:-$(dirname "$0")/out}
NODES=${NODES:-"hot1 hot2 warm1"}
DAYS=${DAYS:-825}
ORG=${ORG:-nosql-lab}

mkdir -p "$OUT"
cd "$OUT"

if [ -f root-ca.pem ]; then
  echo "CA is already in $OUT, nothing to do"
  exit 0
fi

openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days "$DAYS" \
  -subj "/O=$ORG/CN=lab-root-ca" -keyout root-ca-key.pem -out root-ca.pem

# issue NAME USAGE [SAN]: key in PKCS#8 (OpenSearch needs it) and a cert signed by the CA.
issue() {
  name=$1 usage=$2 san=${3:-}
  openssl genrsa -out "$name-key-temp.pem" 2048
  openssl pkcs8 -topk8 -nocrypt -in "$name-key-temp.pem" -out "$name-key.pem"
  openssl req -new -key "$name-key.pem" -subj "/O=$ORG/CN=$name" -out "$name.csr"
  {
    echo "basicConstraints=CA:FALSE"
    echo "keyUsage=critical,digitalSignature,keyEncipherment"
    echo "extendedKeyUsage=$usage"
    if [ -n "$san" ]; then echo "subjectAltName=$san"; fi
  } > "$name.ext"
  openssl x509 -req -in "$name.csr" -CA root-ca.pem -CAkey root-ca-key.pem \
    -CAcreateserial -sha256 -days "$DAYS" -extfile "$name.ext" -out "$name.pem"
  rm -f "$name-key-temp.pem" "$name.csr" "$name.ext"
}

for node in $NODES; do
  issue "$node" serverAuth,clientAuth "DNS:$node,DNS:localhost,IP:127.0.0.1"
done
issue admin clientAuth
issue bento clientAuth

rm -f root-ca.srl
chmod 644 ./*.pem
chmod 600 ./*-key.pem
# The opensearch user in the image has uid 1000.
if [ "$(id -u)" = 0 ]; then chown 1000:1000 ./*.pem; fi

echo "DNs for opensearch.yml:"
for f in $NODES admin bento; do
  printf '  %s: ' "$f"
  openssl x509 -in "$f.pem" -noout -subject -nameopt RFC2253 | sed 's/^subject=//'
done
