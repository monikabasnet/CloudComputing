#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
ca3_verify_target
for tool in openssl keytool kubectl python3; do command -v "$tool" >/dev/null || { echo "Missing $tool" >&2; exit 1; }; done
NS=ca2
OUT="$ROOT/security/tls/generated"
umask 077
mkdir -p "$OUT"
chmod 700 "$OUT"
# Never rotate existing Secrets; fail on API or permission errors.
check_absent() {
  local namespace="$1"
  local name="$2"
  local output

  if output=$(kubectl get secret "$name" -n "$namespace" 2>&1); then
    echo "STOP: Secret $namespace/$name already exists."
    exit 2
  elif [[ "$output" == *"NotFound"* || "$output" == *"not found"* ]]; then
    echo "PASS: $namespace/$name does not exist."
  else
    echo "ERROR: Unable to verify $namespace/$name." >&2
    echo "$output" >&2
    exit 1
  fi
}

kubectl get namespace ca2 >/dev/null
kubectl get namespace monitoring >/dev/null

check_absent monitoring kafka-exporter-ca

for s in kafka-keystore kafka-client-ca mongodb-client-ca \
         mongodb-server-tls mongodb-secret processor-secret; do
  check_absent ca2 "$s"
done

read -r -p 'Type GENERATE-NEW-CA3-SECRETS to generate new credentials: ' confirm
[[ "$confirm" == GENERATE-NEW-CA3-SECRETS ]] || { echo Cancelled; exit 1; }
# Require a fresh empty directory to avoid reusing old key material accidentally.
if find "$OUT" -mindepth 1 -maxdepth 1 | grep -q .; then
  echo "STOP: $OUT is not empty. Review existing private material first." >&2; exit 2
fi
openssl req -x509 -newkey rsa:3072 -sha256 -days 365 -nodes \
  -subj '/CN=CA3 Local Development CA' -keyout "$OUT/ca.key" -out "$OUT/ca.crt" >/dev/null 2>&1
for svc in kafka mongodb; do
  openssl req -new -newkey rsa:3072 -nodes -keyout "$OUT/$svc.key" \
    -out "$OUT/$svc.csr" -config "$ROOT/security/cert-config/$svc-san.cnf" >/dev/null 2>&1
  openssl x509 -req -in "$OUT/$svc.csr" -CA "$OUT/ca.crt" -CAkey "$OUT/ca.key" \
    -CAcreateserial -days 365 -sha256 -out "$OUT/$svc.crt" \
    -extfile "$ROOT/security/cert-config/$svc-san.cnf" -extensions v3_req >/dev/null 2>&1
  openssl verify -CAfile "$OUT/ca.crt" "$OUT/$svc.crt"
done
openssl x509 -in "$OUT/kafka.crt" -noout -checkhost kafka-0.kafka.ca2.svc.cluster.local | grep -q 'does match'
openssl x509 -in "$OUT/mongodb.crt" -noout -checkhost mongodb | grep -q 'does match'
python3 - "$OUT" <<'PY'
import secrets,sys,pathlib
p=pathlib.Path(sys.argv[1])
for name in ('keystore-password.txt','truststore-password.txt','key-password.txt','mongo-password.txt'):
 (p/name).write_text(secrets.token_urlsafe(32))
 (p/name).chmod(0o600)
PY
PASS=$(cat "$OUT/keystore-password.txt")
openssl pkcs12 -export -inkey "$OUT/kafka.key" -in "$OUT/kafka.crt" \
  -certfile "$OUT/ca.crt" -name kafka -out "$OUT/kafka.keystore.p12" -passout "pass:$PASS" >/dev/null 2>&1
keytool -importcert -noprompt -alias ca3-ca -file "$OUT/ca.crt" \
  -keystore "$OUT/kafka.truststore.p12" -storetype PKCS12 \
  -storepass "$(cat "$OUT/truststore-password.txt")" >/dev/null 2>&1
# PKCS12 uses one password for the store and private key.
cp "$OUT/keystore-password.txt" "$OUT/key-password.txt"
cat "$OUT/mongodb.crt" "$OUT/mongodb.key" > "$OUT/mongodb.pem"
chmod 600 "$OUT/mongodb.pem"
# Prepare credentials first. Use existing usernames only when intentionally supplied.
MONGO_USER="${MONGO_USER:-ca3admin}"
MONGO_PASSWORD=$(cat "$OUT/mongo-password.txt")
MONGO_URI=$(MONGO_USER="$MONGO_USER" MONGO_PASSWORD="$MONGO_PASSWORD" python3 - <<'PY'
import os,urllib.parse
u=urllib.parse.quote(os.environ['MONGO_USER'],safe='')
p=urllib.parse.quote(os.environ['MONGO_PASSWORD'],safe='')
print(f'mongodb://{u}:{p}@mongodb:27017/?authSource=admin&tls=true&tlsCAFile=/etc/mongodb-ca/ca.crt')
PY
)
# Processor must mount the CA file referenced by the URI; verify its Deployment first.
if ! grep -q '/etc/mongodb-ca' "$ROOT/processor/deployment.yaml"; then
  echo 'STOP: processor Deployment does not mount /etc/mongodb-ca; no Secrets were created.' >&2
  echo 'Generated files remain in the ignored security/tls/generated directory.' >&2
  exit 2
fi
kubectl create secret generic kafka-keystore -n "$NS" \
  --from-file="$OUT/kafka.keystore.p12" --from-file="$OUT/kafka.truststore.p12" \
  --from-file="$OUT/key-password.txt" --from-file="$OUT/keystore-password.txt" \
  --from-file="$OUT/truststore-password.txt"
# Client CA certificates for application workloads.
kubectl create secret generic kafka-client-ca   -n "$NS"   --from-file="ca.crt=$OUT/ca.crt"

kubectl create secret generic mongodb-client-ca   -n "$NS"   --from-file="ca.crt=$OUT/ca.crt"

# Kafka Exporter runs in the monitoring namespace.
kubectl create secret generic kafka-exporter-ca   -n monitoring   --from-file="ca.crt=$OUT/ca.crt"
kubectl create secret generic mongodb-server-tls -n "$NS" \
  --from-file="ca.crt=$OUT/ca.crt" --from-file="mongodb.pem=$OUT/mongodb.pem"
kubectl create secret generic mongodb-secret -n "$NS" \
  --from-literal=MONGO_INITDB_ROOT_USERNAME="$MONGO_USER" \
  --from-literal=MONGO_INITDB_ROOT_PASSWORD="$MONGO_PASSWORD"
kubectl create secret generic processor-secret -n "$NS" --from-literal=MONGODB_URI="$MONGO_URI"
echo 'Created fresh CA3 TLS and application Secrets. Keep security/tls/ private.'
