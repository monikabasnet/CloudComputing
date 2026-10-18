# CA2 Integrity Packet

## 1. Purpose

This Integrity Packet documents the engineering claims, supporting evidence, validation results, assumptions, known limitations, implementation revisions, and use of AI assistance for CA2 – PaaS Orchestration.

The system implements the authentication-event pipeline:

```text
Producer → Kafka → Processor → MongoDB
                       ↓
                    REST API
```

The application was deployed on Amazon EKS using Kubernetes resources.

This packet distinguishes between:

- features validated against the live EKS environment; and
- later repository refinements that were statically validated after the live cluster was torn down.

---

# 2. Engineering and Design Claims

## Claim 1 — The application ran on Amazon EKS with three worker nodes

The CA2 Kubernetes platform was deployed using Amazon EKS in `us-east-2`.

The cluster contained three managed worker nodes.

### Evidence

- `evidence/02-eks-three-nodes.png`

### Validation

```bash
kubectl get nodes -o wide
```

All three worker nodes were observed in the `Ready` state.

### Status

**Runtime validated.**

---

## Claim 2 — The application preserves the CA0/CA1 logical pipeline

The logical pipeline remains:

```text
Producer → Kafka → Processor → MongoDB
```

The Processor additionally exposes a REST API.

### Evidence

- `evidence/06-end-to-end-pipeline.png`
- `evidence/13-brute-force-processing.png`
- `evidence/15-post-redeploy-pipeline-validation.png`

### Validation

Producer events were published to the Kafka `auth-events` topic.

Processor logs showed events being received and stored:

```text
Received event
Stored event_id=...
```

MongoDB queries confirmed processed events were persisted in the `security_events` collection.

### Status

**Runtime validated.**

---

## Claim 3 — MongoDB uses persistent Kubernetes storage

MongoDB is deployed using a StatefulSet and stores its database files on a dynamically provisioned AWS EBS volume.

### Evidence

- `evidence/03-mongodb-statefulset-pvc.png`
- `evidence/04-kafka-mongodb-statefulsets-pvcs.png`

### Validation

```bash
kubectl get pods,pvc -n ca2
```

The MongoDB Pod was `Running` and its 5 GiB PVC was `Bound`.

The StorageClass used was:

```text
ca2-gp3
```

with the AWS EBS CSI provisioner:

```text
ebs.csi.aws.com
```

### Status

**Runtime validated.**

---

## Claim 4 — Kafka uses persistent EBS storage

Kafka is deployed as a StatefulSet and stores Kafka data on an EBS-backed PVC.

Kafka data is stored under:

```text
/var/lib/kafka/data/kafka
```

### Evidence

- `evidence/04-kafka-mongodb-statefulsets-pvcs.png`
- `evidence/12-kafka-persistent-storage.png`

### Validation

The Kafka PVC was observed in the `Bound` state.

The mounted EBS volume was inspected from inside the Kafka Pod and contained Kafka metadata and consumer-offset directories.

This demonstrated that the PVC was not merely attached; Kafka was actively using it.

### Status

**Runtime validated.**

---

## Claim 5 — Sensitive application credentials are not committed to the repository

MongoDB credentials are supplied at deployment time rather than committed as plaintext.

The final repository includes declarative Secret templates:

```text
mongodb/secret.template.yaml
processor/secret.template.yaml
```

The templates contain placeholders rather than real credentials.

The script:

```text
scripts/create-secrets.sh
```

prompts securely for the MongoDB password.

The username and password are URL-encoded before the Processor MongoDB URI is constructed.

### Validation

The CA2 directory was scanned for common AWS credential and placeholder-secret patterns.

The final scan returned no matching real credentials.

The Secret template YAML files were parsed successfully during static validation.

The shell script passed `bash -n`.

### Status

The original runtime Secret workflow was **runtime validated**.

The final declarative-template refinement was added after cluster teardown and was **statically validated**, not rerun against the deleted EKS environment.

---

## Claim 6 — Network isolation is enforced

Kubernetes NetworkPolicies restrict access to Kafka and MongoDB.

### Kafka policy

Kafka permits TCP port `9092` traffic from:

```text
Producer
Processor
```

### MongoDB policy

MongoDB permits TCP port `27017` traffic from:

```text
Processor
```

### Evidence

- `evidence/07-network-policy-enforcement.png`

### Validation

Amazon VPC CNI NetworkPolicy enforcement was enabled.

An unauthorized test Pod attempted to connect to MongoDB and received:

```text
Connection timed out
```

The Processor was then tested against MongoDB and returned:

```text
Processor -> MongoDB: ALLOWED
```

This demonstrated both denied and permitted network paths.

### Status

**Runtime validated.**

---

## Claim 7 — Kubernetes RBAC follows least privilege

The Processor uses a dedicated ServiceAccount:

```text
processor-sa
```

A namespace Role permits the ServiceAccount to read ConfigMaps.

It does not permit destructive Pod operations.

### Evidence

- `evidence/08-rbac-least-privilege.png`

### Validation

Allowed operation:

```bash
kubectl auth can-i get configmaps \
  --as=system:serviceaccount:ca2:processor-sa \
  -n ca2
```

Result:

```text
yes
```

Unauthorized operation:

```bash
kubectl auth can-i delete pods \
  --as=system:serviceaccount:ca2:processor-sa \
  -n ca2
```

Result:

```text
no
```

### Status

**Runtime validated.**

---

## Claim 8 — The Processor REST endpoint is functional

The Processor exposes a REST API on port `8080`.

### Evidence

- `evidence/05-processor-rest-health.png`

### Validation

The Processor Service was forwarded locally:

```bash
kubectl port-forward -n ca2 service/processor 8080:8080
```

The health endpoint was tested with:

```bash
curl http://localhost:8080/health
```

The response was:

```json
{"kafka_topic":"auth-events","mongodb":"connected","status":"ok"}
```

This demonstrated that the REST service was running and MongoDB connectivity was healthy.

### Status

**Runtime validated.**

---

## Claim 9 — Horizontal scaling increases Producer throughput

The Producer was tested with one replica and three replicas using equal 30-second measurement windows.

### Evidence

- `evidence/09-producer-scaling-throughput.png`

### Results

| Producer replicas | Events processed | Duration | Approx. throughput |
|---:|---:|---:|---:|
| 1 | 31 | 30 seconds | 1.03 events/sec |
| 3 | 98 | 30 seconds | 3.27 events/sec |

Observed throughput improvement:

```text
approximately 3.16x
```

### Interpretation

Increasing the Producer replica count from one to three increased the rate at which authentication events entered and passed through the pipeline during this test.

### Status

**Runtime validated.**

A repeatable `scaling-test.sh` helper was later added to encode the same measurement procedure. That helper was statically validated after cluster teardown.

---

## Claim 10 — Kubernetes resource metrics are available

Metrics Server provides CPU and memory measurements for application Pods.

### Validation

```bash
kubectl top pods -n ca2
```

returned CPU and memory measurements for:

- Kafka
- MongoDB
- Processor
- Producer

These metrics were also available to the Horizontal Pod Autoscaler.

### Status

**Runtime validated.**

---

## Claim 11 — The Producer uses automatic horizontal scaling

A Kubernetes HorizontalPodAutoscaler manages the Producer Deployment.

Configuration:

```text
Minimum replicas: 1
Maximum replicas: 3
CPU target: 50%
```

### Evidence

- `evidence/10-hpa-autoscaling.png`

### Validation

The Producer had previously been scaled to three replicas.

With CPU utilization around 4%, the HPA automatically reduced the Producer Deployment to one replica.

This demonstrated automatic scale-down behavior using CPU metrics.

### Limitation

A sustained CPU-load experiment forcing HPA automatic scale-up from one replica to multiple replicas was not performed.

### Status

**Automatic HPA scale-down runtime validated.**

Automatic HPA scale-up was **not demonstrated** and is not claimed.

---

## Claim 12 — Brute-force-style authentication activity is detected

The Processor tracks repeated failed login attempts.

As failed attempts accumulated, processed events were classified as:

```text
POSSIBLE_BRUTE_FORCE
```

### Evidence

- `evidence/13-brute-force-processing.png`

### Validation

Processor logs showed increasing failed-attempt counters together with successful MongoDB inserts.

Example:

```text
Received event
Stored event ... status=POSSIBLE_BRUTE_FORCE
```

### Status

**Runtime validated.**

---

## Claim 13 — Application deployment is reproducible

The project includes Makefile targets for deployment and cleanup.

Application deployment:

```bash
make -C CA2 deploy
```

Application removal:

```bash
make -C CA2 destroy
```

EKS cluster creation:

```bash
make -C CA2 cluster-up
```

EKS cluster removal:

```bash
make -C CA2 cluster-down
```

### Evidence

- `evidence/14-automated-redeployment.png`
- `evidence/15-post-redeploy-pipeline-validation.png`

### Validation

The `ca2` namespace was deleted and confirmed absent.

The complete application was recreated using:

```bash
make -C CA2 deploy
```

After deployment:

```text
Kafka       Running
MongoDB     Running
Processor   Running
Producer    Running
Kafka PVC   Bound
MongoDB PVC Bound
```

No manual Processor restart was required during the final validation.

Processor logs subsequently showed new events being consumed and stored in MongoDB.

### Status

**Runtime validated for the deployed version captured in evidence.**

Later Secret-template and Producer init-container refinements were statically validated after cluster teardown.

---

## Claim 14 — Processor startup dependency is handled explicitly

During development, the Processor could start before Kafka was ready and fail with:

```text
NoBrokersAvailable
```

The Processor Deployment was revised to include a `wait-for-kafka` init container.

The init container waits until:

```text
kafka:9092
```

is reachable before the Processor starts.

### Validation

During the final destroy/redeploy test, the Processor successfully started after Kafka became available without requiring a manual restart.

### Status

**Runtime validated.**

---

## Claim 15 — The final Producer manifest handles Kafka startup ordering

The final Producer Deployment also contains a `wait-for-kafka` init container.

This prevents the Producer application container from starting before Kafka is reachable.

### Validation

The final YAML parsed successfully during static validation.

### Status

**Statically validated only.**

This refinement was added after the EKS cluster had already been torn down and was not rerun against the live environment.

---

## Claim 16 — Repeatable validation helpers are provided

The final repository includes:

```text
scripts/smoke-test.sh
scripts/scaling-test.sh
scripts/evidence.sh
```

The Makefile exposes:

```text
make smoke-test
make scaling-test
make evidence
```

### Validation

All helper scripts passed:

```bash
bash -n
```

All Makefile targets were checked using:

```bash
make -n
```

The evidence helper includes:

```text
kubectl get all -A
```

as requested by the assignment.

### Status

**Statically validated.**

The helper scripts were added after the live EKS cluster had been deleted.

---

# 3. Validation Summary

| Validation | Result | Type |
|---|---|---|
| Three EKS worker nodes | PASS | Runtime |
| Kafka Pod running | PASS | Runtime |
| MongoDB Pod running | PASS | Runtime |
| Processor Pod running | PASS | Runtime |
| Producer Pod running | PASS | Runtime |
| MongoDB PVC Bound | PASS | Runtime |
| Kafka PVC Bound | PASS | Runtime |
| Kafka actively writing to EBS | PASS | Runtime |
| MongoDB authentication | PASS | Runtime |
| Kafka topic available | PASS | Runtime |
| Producer publishes events | PASS | Runtime |
| Processor consumes events | PASS | Runtime |
| Processor stores events in MongoDB | PASS | Runtime |
| REST `/health` endpoint | PASS | Runtime |
| Unauthorized MongoDB connection blocked | PASS | Runtime |
| Authorized Processor → MongoDB connection | PASS | Runtime |
| RBAC allowed action | PASS | Runtime |
| RBAC denied action | PASS | Runtime |
| Metrics Server CPU/memory metrics | PASS | Runtime |
| Producer 1 → 3 replica scaling | PASS | Runtime |
| Throughput measurement | PASS | Runtime |
| HPA automatic scale-down | PASS | Runtime |
| HPA automatic scale-up | NOT TESTED | Documented limitation |
| Brute-force classification | PASS | Runtime |
| Application destroy | PASS | Runtime |
| Automated application redeployment | PASS | Runtime |
| Post-redeploy event processing | PASS | Runtime |
| Repository secret scan | PASS | Static |
| 17 YAML files parsed | PASS | Static |
| Shell-script syntax validation | PASS | Static |
| Makefile dry-run targets | PASS | Static |
| Declarative Secret templates | PASS | Static |
| Producer wait-for-Kafka refinement | PASS | Static |
| Evidence helper with `kubectl get all -A` | PASS | Static |
| Final EKS cluster teardown | PASS | Runtime/AWS |

---

# 4. Evidence Index

| Evidence | Description |
|---|---|
| `01-ca2-eks-iam-permissions.png` | IAM permissions used to support CA2 deployment |
| `02-eks-three-nodes.png` | Three EKS worker nodes in Ready state |
| `03-mongodb-statefulset-pvc.png` | MongoDB Pod running with Bound persistent storage |
| `04-kafka-mongodb-statefulsets-pvcs.png` | Kafka and MongoDB running with Bound PVCs |
| `05-processor-rest-health.png` | Successful REST `/health` response |
| `06-end-to-end-pipeline.png` | Event successfully processed through the pipeline |
| `07-network-policy-enforcement.png` | Network isolation validation |
| `08-rbac-least-privilege.png` | RBAC allowed and denied operations |
| `09-producer-scaling-throughput.png` | One-replica versus three-replica throughput |
| `10-hpa-autoscaling.png` | HPA automatic scale-down |
| `11-full-kubernetes-stack.png` | Complete Kubernetes application stack |
| `12-kafka-persistent-storage.png` | Kafka files stored on EBS-backed storage |
| `13-brute-force-processing.png` | Repeated failed login detection and persistence |
| `14-automated-redeployment.png` | Healthy resources following automated redeployment |
| `15-post-redeploy-pipeline-validation.png` | Event processing working after redeployment |

---

# 5. Assumptions

The following assumptions were made:

1. AWS region `us-east-2` is used consistently.
2. The AWS CLI profile used for deployment is named `ca2`.
3. Docker is available when application images need to be rebuilt.
4. The required Producer and Processor images exist in private ECR repositories before application deployment.
5. A user running `make deploy` has access to the EKS cluster through `kubectl`.
6. The user supplies the MongoDB password interactively during deployment.
7. EKS worker nodes have access to the private ECR repositories.
8. The EBS CSI driver and required EKS platform components are available before application deployment.
9. The EBS CSI Pod Identity IAM prerequisite is configured by an identity with sufficient IAM permissions.
10. `envsubst` is installed for rendering the final Secret templates.

---

# 6. Known Limitations

1. Kafka is deployed as a single broker. This demonstrates Kubernetes orchestration and persistence but does not provide multi-broker Kafka high availability.

2. MongoDB is deployed as a single StatefulSet replica rather than a MongoDB replica set.

3. The Processor REST API uses Flask's development server. It is sufficient for course validation but would normally be replaced by a production WSGI server.

4. Producer throughput measurements used short 30-second windows. They demonstrate scaling behavior but are not comprehensive performance benchmarks.

5. The HPA demonstration verified automatic scale-down under low CPU. A sustained CPU-load experiment forcing automatic HPA scale-up was not performed.

6. Both Producer and Processor Deployments now include `wait-for-kafka` init containers. The Processor startup fix was validated during the live destroy/redeploy test. The later Producer init-container refinement was statically validated after cluster teardown and was not rerun against the deleted EKS environment.

7. Kubernetes Secrets protect credentials from being committed to Git, but standard Kubernetes Secrets are not equivalent to a dedicated external secrets-management platform.

8. EBS CSI Pod Identity role creation remains a documented cluster-level IAM prerequisite because the restricted deployment identity did not have unrestricted IAM role-creation permissions.

9. The final declarative Secret-template workflow and helper scripts were added after the live EKS cluster had been deleted. They passed static syntax/YAML checks but were not rerun against the live environment.

10. The original screenshot set does not contain a literal `kubectl get all -A` capture. The final `evidence.sh` helper now includes that exact command for future deployments.

---

# 7. Problems Encountered and Engineering Revisions

Several implementation issues were identified during testing and corrected.

## EBS CSI IAM Permissions

The EBS CSI controller initially lacked the AWS permissions required to manage EBS volumes.

EKS Pod Identity and the recommended EBS CSI managed policy were configured for the controller.

## MongoDB Credential Mismatch

MongoDB authentication initially failed during testing.

The Secret and persistent volume were recreated during development, and the exact Kubernetes Secret value was used to verify authentication.

## Special Characters in MongoDB Password

A MongoDB password containing URL-sensitive characters caused the Processor MongoDB URI to be invalid.

The secret-creation workflow was revised to URL-encode credentials before constructing `MONGODB_URI`.

## Processor Starting Before Kafka

The Processor initially encountered:

```text
NoBrokersAvailable
```

during fresh deployment.

The Deployment was revised to include a Kafka-wait init container.

## Producer Startup Ordering

The original Producer could restart while Kafka was still becoming available.

The final Producer Deployment was updated with the same Kafka-wait pattern.

Because this refinement was added after cluster teardown, it received static rather than live validation.

## Kafka PVC Initially Unused

Kafka initially wrote data to temporary container storage even though a PVC was attached.

`KAFKA_LOG_DIRS` was explicitly configured to use the mounted EBS path.

## Kafka EBS Filesystem Permissions

Kafka initially lacked permission to write to the EBS mount.

A Pod security context using:

```text
fsGroup: 1000
```

was added.

## Kafka and `lost+found`

Using the root of the EBS filesystem caused Kafka to interpret `lost+found` as an invalid Kafka log directory.

Kafka storage was moved to:

```text
/var/lib/kafka/data/kafka
```

which resolved the issue.

## Secret Declarative Completeness

The original runtime workflow created Secrets imperatively.

The final repository adds declarative Secret template manifests while still keeping actual credentials outside Git.

This refinement was statically validated after the live cluster was removed.

---

# 8. AI Assistance

AI assistance was used during CA2 as an engineering support tool.

AI was used for:

- explaining Kubernetes and AWS concepts;
- suggesting Kubernetes YAML structures;
- troubleshooting AWS IAM and EBS CSI errors;
- troubleshooting MongoDB authentication;
- troubleshooting Kafka persistent-storage configuration;
- designing validation commands;
- designing NetworkPolicy and RBAC tests;
- creating the scaling measurement procedure;
- improving deployment reproducibility;
- organizing documentation and evidence;
- reviewing the final repository against the assignment rubric.

AI-generated suggestions were not accepted without validation.

## Examples of AI Guidance That Was Tested and Revised

### EBS CSI Configuration

Initial storage-driver configuration required additional IAM troubleshooting.

AWS CLI output and Kubernetes Pod behavior were used to identify missing permissions before the final configuration was accepted.

### MongoDB Authentication

Initial assumptions about authentication failures were revised after testing the exact Kubernetes Secret value and MongoDB authentication behavior.

### MongoDB URI Encoding

A password containing URL-sensitive characters produced an invalid MongoDB URI.

The implementation was revised to URL-encode credentials.

### Kafka Persistence

The initial Kafka StatefulSet attached a PVC but Kafka was still writing to temporary storage.

The mounted volume and Kafka logs were inspected, and the configuration was revised until Kafka files were visibly stored on the EBS-backed path.

### Kafka Filesystem Path

The first persistent Kafka log path used the filesystem root and failed because of `lost+found`.

Kafka logs were moved into a dedicated subdirectory after validating the failure through Kafka logs.

### Processor Startup

The initial Processor deployment could start before Kafka.

After reproducing `NoBrokersAvailable`, an init container was added and the complete destroy/redeploy test was repeated.

### NetworkPolicy

The existence of NetworkPolicy YAML alone was not accepted as evidence.

VPC CNI NetworkPolicy support was enabled and both blocked and allowed traffic paths were tested.

### RBAC

Least-privilege behavior was verified using:

```bash
kubectl auth can-i
```

rather than inferred only from the manifest.

### Final Repository Refinements

Later AI-assisted recommendations added:

- declarative Secret templates;
- Producer startup waiting;
- repeatable smoke-test automation;
- repeatable scaling-test automation;
- an evidence-collection helper.

Because the live cluster had already been deleted, these later refinements were statically validated and are explicitly identified as such rather than represented as runtime-tested.

---

# 9. Official Documentation and AI Guidance Verification

Generative AI guidance was treated as a starting point rather than an authoritative source.

Consequential guidance was cross-checked against official Kubernetes and Amazon EKS documentation and validated through observed runtime behavior when the live environment was available.

Relevant topics included:

- StatefulSets
- PersistentVolumeClaims
- StorageClasses
- Services
- ConfigMaps
- Secrets
- NetworkPolicy
- ServiceAccounts
- Roles and RoleBindings
- Horizontal Pod Autoscaler
- resource requests and metrics
- Amazon EKS add-ons
- AWS EBS CSI driver
- Amazon EKS Pod Identity
- Amazon VPC CNI NetworkPolicy support

AI-assisted recommendations were tested using commands and evidence such as:

```text
kubectl get
kubectl logs
kubectl exec
kubectl auth can-i
kubectl top
curl
aws eks
eksctl
```

Guidance was revised or rejected when observed behavior did not support it.

## Official References Reviewed

The final design was cross-checked against official documentation covering:

- Kubernetes StatefulSets: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/
- Kubernetes Storage: https://kubernetes.io/docs/concepts/storage/
- Kubernetes Configuration, ConfigMaps, and Secrets: https://kubernetes.io/docs/concepts/configuration/
- Kubernetes Services and NetworkPolicy: https://kubernetes.io/docs/concepts/services-networking/
- Kubernetes RBAC: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- Kubernetes application scaling and HPA: https://kubernetes.io/docs/tasks/run-application/
- Amazon EKS EBS CSI driver: https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html
- Amazon EKS Pod Identity: https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html
- Amazon EKS VPC CNI NetworkPolicy: https://docs.aws.amazon.com/eks/latest/userguide/cni-network-policy-configure.html

These official sources were used as authoritative references for the Kubernetes and EKS concepts implemented in CA2.

---

# 10. Static Validation of Final Repository

After the live EKS environment was removed, the final repository refinements were statically audited.

## Shell Scripts

The following scripts passed `bash -n`:

```text
scripts/create-secrets.sh
scripts/evidence.sh
scripts/scaling-test.sh
scripts/setup-cluster.sh
scripts/smoke-test.sh
```

## YAML

Seventeen YAML files were parsed successfully using PyYAML.

This included:

- EKS configuration
- Namespace
- Kafka resources
- MongoDB resources
- Processor resources
- Producer resources
- NetworkPolicy
- RBAC
- HPA
- Secret templates

## Makefile

The following targets were previewed successfully using `make -n`:

```text
cluster-up
cluster-setup
deploy
smoke-test
scaling-test
evidence
destroy
cluster-down
```

## Credential Scan

The repository was scanned for common AWS credential and placeholder-password patterns.

No matching real credentials were found.

## Evidence

All 15 PNG evidence files remained present.

## Git Validation

`git diff --check` returned no whitespace errors before the final commit.

---

# 11. Final Assessment

The CA2 implementation demonstrates the required PaaS orchestration concepts through a functioning Kubernetes deployment on Amazon EKS.

Runtime evidence demonstrates:

- a three-node EKS cluster;
- Producer → Kafka → Processor → MongoDB processing;
- a working REST endpoint;
- Kafka and MongoDB persistent EBS storage;
- NetworkPolicy enforcement;
- least-privilege RBAC;
- Metrics Server observability;
- horizontal Producer scaling;
- approximately 3.16x measured throughput improvement;
- HPA automatic scale-down;
- brute-force event classification;
- automated application destruction and redeployment;
- successful post-redeployment event processing;
- successful EKS teardown.

The final repository additionally contains statically validated improvements for:

- declarative Secret templates;
- Producer Kafka startup waiting;
- repeatable smoke testing;
- repeatable scaling testing;
- exact `kubectl get all -A` evidence collection.

The distinction between runtime-tested behavior and later static refinements is documented explicitly so the Integrity Packet does not overstate the evidence.

All major engineering claims are tied to observed validation results, captured evidence, static validation, or clearly documented limitations.
