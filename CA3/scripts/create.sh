#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
for tool in aws eksctl kubectl helm; do command -v "$tool" >/dev/null || { echo "Missing $tool"; exit 1; }; done
ACCOUNT=$(aws sts get-caller-identity --profile "$CA3_PROFILE" --query Account --output text)
[[ -n "$ACCOUNT" && "$ACCOUNT" != None ]] || exit 1
if aws eks describe-cluster --name "$CA3_CLUSTER" --region "$CA3_REGION" --profile "$CA3_PROFILE" >/dev/null 2>&1; then
 echo 'Cluster already exists; refusing to overwrite it.'; exit 1
fi
cat <<'MSG'
PREFLIGHT BLOCKED: Full fresh-cluster creation is not reproducible from the supplied archive yet.
Missing version-controlled or automated prerequisites include:
- EBS CSI add-on and IAM/Pod Identity bootstrap;
- creation of Kafka PKCS12 keystores and truststore, and MongoDB TLS certificates;
- creation of kafka-keystore, kafka-client-ca, kafka-exporter-ca,
  mongodb-server-tls, mongodb-secret and processor-secret;
- ConfigMaps, ServiceAccounts/RBAC, MongoDB Service, processor Service;
- verified ECR image build/push and Helm chart repository setup;
- validated monitoring installation order and fresh-install smoke test.
No AWS resources were created. Do NOT bypass this preflight.
MSG
exit 2
