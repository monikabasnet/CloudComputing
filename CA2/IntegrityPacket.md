# CA2 Integrity Packet

## 1. Purpose

This Integrity Packet documents the engineering claims, supporting evidence, validation results, assumptions, limitations, and use of AI assistance for CA2 – PaaS Orchestration.

The system implements the authentication-event pipeline:

```text
Producer → Kafka → Processor → MongoDB
                       ↓
                    REST API
```

The application is deployed on Amazon EKS using Kubernetes resources.

---

# 2. Engineering and Design Claims

## Claim 1 – The application runs on Amazon EKS with three worker nodes

The CA2 Kubernetes platform was deployed using Amazon EKS in `us-east-2`.

The cluster contains three managed worker nodes.

### Evidence

- `evidence/02-eks-three-nodes.png`

### Validation

```bash
kubectl get nodes -o wide
```

All three worker nodes were observed in the `Ready` state.

---

## Claim 2 – The application preserves the CA0/CA1 logical pipeline

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

---

## Claim 3 – MongoDB uses persistent Kubernetes storage

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

---

## Claim 4 – Kafka uses persistent EBS storage

Kafka is deployed as a StatefulSet and stores Kafka data on its EBS-backed PVC.

Kafka data is stored under:

```text
/var/lib/kafka/data/kafka
```

### Evidence

- `evidence/04-kafka-mongodb-statefulsets-pvcs.png`
- `evidence/12-kafka-persistent-storage.png`

### Validation

The Kafka PVC was observed in the `Bound` state.

The mounted volume was inspected inside the Kafka Pod and contained Kafka files including cluster metadata and consumer-offset directories.

This confirmed that the PVC was not merely attached; Kafka was actively using it.

---

## Claim 5 – Sensitive application credentials are not committed to the repository

MongoDB credentials are created during deployment rather than stored as plaintext in Git.

### Design

The script:

```text
scripts/create-secrets.sh
```

prompts for the MongoDB password and creates:

```text
mongodb-secret
processor-secret
```

The password is not written into the repository.

The MongoDB username and password are URL-encoded before constructing the Processor MongoDB URI so special characters can be used safely.

### Validation

The CA2 directory was searched for common AWS credential and placeholder-secret patterns before submission.

The final scan did not return matching credentials.

---

## Claim 6 – Network isolation is enforced

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

---

## Claim 7 – Kubernetes RBAC follows least privilege

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

---

## Claim 8 – The Processor REST endpoint is functional

The Processor exposes a REST API on port `8080`.

### Evidence

- `evidence/05-processor-rest-health.png`

### Validation

The Processor Service was temporarily forwarded locally:

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

---

## Claim 9 – Horizontal scaling increases Producer throughput

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

---

## Claim 10 – Kubernetes resource metrics are available

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

These metrics are also available to the Horizontal Pod Autoscaler.

---

## Claim 11 – The Producer uses automatic horizontal scaling

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

---

## Claim 12 – Brute-force-style authentication activity is detected

The Processor tracks repeated failed login attempts.

As failed attempts accumulated, processed events were classified as:

```text
POSSIBLE_BRUTE_FORCE
```

### Evidence

- `evidence/13-brute-force-processing.png`

### Validation

Processor logs showed increasing failed-attempt counters together with successful MongoDB inserts.

Example behavior:

```text
Received event
Stored event ... status=POSSIBLE_BRUTE_FORCE
```

---

## Claim 13 – Deployment is reproducible

The project includes a Makefile for deployment and cleanup.

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

The complete application was then recreated using:

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

No manual Pod restart was required during the final validation.

Processor logs subsequently showed new events being consumed and stored in MongoDB.

---

## Claim 14 – Startup dependencies are handled during deployment

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

---

# 3. Validation Summary

The following validation activities were completed.

| Validation | Result |
|---|---|
| Three EKS worker nodes | PASS |
| Kafka Pod running | PASS |
| MongoDB Pod running | PASS |
| Processor Pod running | PASS |
| Producer Pod running | PASS |
| MongoDB PVC Bound | PASS |
| Kafka PVC Bound | PASS |
| Kafka actually writing to EBS volume | PASS |
| MongoDB authentication | PASS |
| Kafka topic available | PASS |
| Producer publishes events | PASS |
| Processor consumes events | PASS |
| Processor stores events in MongoDB | PASS |
| REST `/health` endpoint | PASS |
| Unauthorized MongoDB connection blocked | PASS |
| Authorized Processor → MongoDB connection | PASS |
| RBAC allowed action | PASS |
| RBAC denied action | PASS |
| Metrics Server CPU/memory metrics | PASS |
| Producer 1 → 3 replica scaling | PASS |
| Throughput measurement | PASS |
| HPA automatic scale-down | PASS |
| Brute-force classification | PASS |
| Application destroy | PASS |
| Automated application redeployment | PASS |
| Post-redeploy event processing | PASS |
| Repository secret scan | PASS |

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
| `10-hpa-autoscaling.png` | HPA automatic replica adjustment |
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
4. The required Producer and Processor images exist in the private ECR repositories before application deployment.
5. A user running `make deploy` has access to the EKS cluster through `kubectl`.
6. The user supplies the MongoDB password interactively during deployment.
7. EKS worker nodes have access to the private ECR repositories.
8. The EBS CSI driver and required EKS platform components are available on the cluster.

---

# 6. Known Limitations

The following limitations are known:

1. Kafka is deployed as a single broker. This demonstrates Kubernetes orchestration and persistence but does not provide multi-broker Kafka high availability.

2. MongoDB is deployed as a single StatefulSet replica rather than a MongoDB replica set.

3. The Processor REST API uses Flask's development server. It is sufficient for this course validation but would normally be replaced by a production WSGI server for production use.

4. Producer throughput measurements were short 30-second experiments. They demonstrate scaling behavior but are not intended to be comprehensive performance benchmarks.

5. The HPA demonstration verified automatic scale-down under low CPU. A sustained CPU-load experiment that forces automatic scale-up was not performed.

6. The Producer may restart during early deployment if Kafka is not yet ready. The Processor explicitly handles this dependency through its `wait-for-kafka` init container.

7. Kubernetes Secrets protect credentials from being committed to Git, but standard Kubernetes Secrets are not encrypted application-level vaults by themselves. Additional production environments could integrate an external secrets manager.

8. The EKS cluster and some AWS add-on configuration are managed separately from the application manifests. Application deployment is automated through the Makefile, while cluster-level dependencies must exist before `make deploy`.

---

# 7. Problems Encountered and Engineering Revisions

Several implementation issues were identified during testing and corrected.

## EBS CSI IAM permissions

The EBS CSI controller initially lacked the AWS permissions required to manage EBS volumes.

EKS Pod Identity and the recommended EBS CSI managed policy were configured for the controller.

## MongoDB credential mismatch

MongoDB authentication initially failed during testing.

The Secret and persistent volume were recreated during development, and the exact Kubernetes Secret value was used to verify successful authentication.

## Special characters in MongoDB password

A MongoDB password containing URL-sensitive characters caused the Processor MongoDB URI to be invalid.

The secret-creation script was revised to URL-encode credentials before constructing `MONGODB_URI`.

## Processor starting before Kafka

The Processor initially encountered:

```text
NoBrokersAvailable
```

during fresh deployment.

The Deployment was revised to include a Kafka-wait init container.

## Kafka PVC initially unused

Kafka initially wrote data to temporary container storage even though a PVC was attached.

`KAFKA_LOG_DIRS` was explicitly configured to use the mounted EBS path.

## Kafka EBS filesystem permissions

Kafka initially lacked permission to write to the EBS mount.

A Pod security context with:

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

These changes were retained in the final declarative configuration.

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
- organizing documentation and evidence.

AI-generated suggestions were not accepted without validation.

Examples of suggestions that were tested and revised include:

### EBS CSI configuration

Initial storage-driver configuration required additional IAM troubleshooting. AWS CLI output and Kubernetes Pod logs were used to identify the missing permissions before the final configuration was accepted.

### MongoDB authentication

Initial assumptions about the authentication failure were revised after inspecting MongoDB logs and testing the exact Kubernetes Secret value.

### Kafka persistence

The initial Kafka StatefulSet attached a PVC but Kafka was still writing to temporary storage. Inspection of the mounted volume and Kafka logs identified the problem. The configuration was revised until Kafka files were visibly stored on the EBS-backed path.

### Kafka filesystem path

The first persistent Kafka log path used the filesystem root and failed because of `lost+found`. Kafka logs were moved into a dedicated subdirectory after validating the failure through Kafka logs.

### Processor startup

The initial Processor deployment could start before Kafka. After reproducing `NoBrokersAvailable`, an init container was added and the complete destroy/redeploy test was repeated.

### Final acceptance process

AI suggestions were accepted only after validation using commands such as:

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

When observed behavior disagreed with an assumption, the configuration was revised and retested.

The final claims in this packet are based on observed command output and captured evidence rather than AI-generated claims alone.

---

# 9. Final Assessment

The final CA2 implementation demonstrates the required PaaS orchestration concepts through a functioning Kubernetes deployment on Amazon EKS.

The project includes:

- declarative Kubernetes application resources;
- persistent stateful workloads;
- secure runtime credential injection;
- network isolation;
- least-privilege RBAC;
- metrics collection;
- manual horizontal scaling with measured results;
- automatic HPA behavior;
- a working REST endpoint;
- end-to-end event processing;
- automated application deployment and destruction;
- successful destroy/redeploy validation;
- documented limitations and engineering revisions.

All major claims in this Integrity Packet are tied to observed validation results or evidence stored in the repository.