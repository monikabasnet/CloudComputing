# CA3 Integrity Packet — Engineering Claims, Evidence and Verification

**CS5287 Cloud Computing | 8 November 2026**

## 1. Purpose and verification standard

This packet documents the engineering claims, test results, assumptions, troubleshooting, AI-assisted decisions, limitations, and supporting evidence for **CA3 — Cloud-Native Observability, Autoscaling, Security Hardening and Resilience**. It builds on the CA2 Integrity Packet's claim–evidence–validation format, which received full credit, while addressing the CA2 instructor's specific feedback about automatic HPA scale-up, comprehensive network isolation, deployment ordering, and automated REST verification.

**Verification levels:**

- **Runtime verified:** observed command output or an actual live-cluster test.
- **Configuration verified:** source or deployed configuration inspected, but the specific behavior may not have been exercised.
- **Syntax validated only:** file parses successfully; operational behavior untested.
- **Pending / not tested:** evidence insufficient to claim success.

The pipeline is **Producer → Kafka (`auth-events`) → Processor → MongoDB**, with a processor REST API. Screenshot references are relative to [`evidence/`](evidence/). A screenshot's existence is not a substitute for describing the actual observation.

## 2. Claim-to-evidence matrix

| ID | Engineering claim | Evidence and observation | Verification |
|---|---|---|---|
| C01 | EKS platform supports the CA3 application | Three-node `ca3-eks-cluster`; final Deployments and StatefulSets each `1/1` | Runtime verified; [01](evidence/01-eks-nodes-ready.png), [36](evidence/36-final-cluster-health.png) |
| C02 | End-to-end event pipeline operates | Matching producer/processor event IDs and Kafka offsets `54413–54415`; processor logs include MongoDB IDs | Runtime verified; [05](evidence/05-complete-pipeline-running.png), [36](evidence/36-final-cluster-health.png) |
| C03 | Observability stack collects metrics | kube-prometheus-stack, Kafka Exporter and metrics targets; instrumented app metrics | Runtime verified/configuration inspected; [07](evidence/07-ca3-instrumented-pods.png)–[15](evidence/15-grafana-six-panels.png) |
| C04 | Centralized logging and correlation available | Loki/Alloy logs for applications, Kafka and MongoDB; event correlation | Runtime evidence; [16](evidence/16-loki-centralized-logs.png)–[16d](evidence/16d-loki-mongodb-logs.png) |
| C05 | Kafka consumer lag can be monitored | Exporter showed `kafka_brokers=1` and `kafka_consumergroup_lag_sum=0` for `ca0-threat-processor` | Runtime verified; [14](evidence/14-kafka-consumer-lag-baseline.png), [14b](evidence/14b-kafka-exporter-metric.png) |
| C06 | CPU-based producer HPA scales up automatically | Load test raised utilization to `251%/50%`; replicas reached 3 | Runtime verified; [33](evidence/33-producer-hpa-scale-up.png) |
| C07 | Producer HPA scales down after load | Utilization fell to ~`2%/50%`; replicas decreased and final HPA showed 1 | Runtime verified; [34](evidence/34-producer-hpa-scale-down.png), [36](evidence/36-final-cluster-health.png) |
| C08 | Processor HPA is configured and active | `processor-hpa` min 1, max 3, CPU target 50%; final utilization `3%/50%` | Runtime verified for operation; [17](evidence/17-hpa-scale-up.png)–[19](evidence/19-hpa-pipeline-recovery.png), [36](evidence/36-final-cluster-health.png) |
| C09 | Kafka client listener uses TLS | `listeners=CONTROLLER://:9093,SSL://:9094`, `advertised.listeners=SSL://kafka-0.kafka.ca2.svc.cluster.local:9094` | Runtime configuration verified; [28](evidence/28-kafka-tls-only.png) |
| C10 | MongoDB requires TLS | `mongod` process includes `--tlsMode requireTLS` and CA/cert paths | Runtime configuration verified; [26](evidence/26-mongodb-tls-verified.png), [27](evidence/27-mongodb-requiretls-enforcement.png) |
| C11 | NetworkPolicy restricts unauthorized producer → MongoDB traffic | Producer → Kafka 9094 connected; producer → MongoDB 27017 timed out; processor → MongoDB connected | Runtime connectivity verified; [35](evidence/35-networkpolicy-enforcement.png) |
| C12 | EKS NetworkPolicy enforcement configured | VPC CNI add-on reported `enableNetworkPolicy=true`, mode `standard`; seven policies active | Runtime/configuration verified; [21](evidence/21-networkpolicy-enabled.png), [36](evidence/36-final-cluster-health.png) |
| C13 | Producer Pod recovers after deletion | Replacement producer became ready and resumed publishing | Runtime verified; [29](evidence/29-resilience-pod-recovery.png) |
| C14 | Processor recovers after interruption | Replacement processor ready; resumed event processing and MongoDB writes | Runtime verified; [30](evidence/30-processor-resilience-recovery.png) |
| C15 | Kafka restarts using existing PVC | Planned shutdown and restart; original Kafka PVC remained bound; producer/processor resumed, lag zero | Runtime verified for restart, **not** snapshot restore; [31](evidence/31-kafka-resilience-recovery.png) |
| C16 | MongoDB Pod recovers using retained PVC | Pod recreated with changed Pod IP; original PVC remained bound; processor writes resumed | Runtime verified; [32](evidence/32-mongodb-resilience-recovery.png) |
| C17 | MongoDB archive backup was created | TLS-authenticated `mongodump` completed with 52,565 documents; 2.0 MiB archive; `gzip -t` passed | Runtime verified for backup/integrity, **not** restore |
| C18 | Kafka stopped-broker EBS snapshot completed | `snap-0bc48882d896e1546`, `completed`, `100%`; source EBS volume matched Kafka PV | Runtime verified for snapshot creation, **not** restore |
| C19 | Automated REST verification works | `/health`, `/events`, `/alerts`, `/metrics` all passed; events and alerts returned arrays of 100 | Runtime verified; [38](evidence/38-automated-rest-verification.png) |
| C20 | Operational status script works | `status.sh` listed active cluster, three workers, application/monitoring workloads and five retained PVs | Runtime verified; [37](evidence/37-automation-status.png) |
| C21 | Pause/resume scripts safely block premature execution | `bash -n` passed and both scripts printed `SAFETY STOP` then exited | Syntax and guard behavior verified; actual pause/resume **not tested** |
| C22 | Fresh-cluster create/full teardown is reproducible | Full CA3 `create.sh` and `teardown.sh` not yet completed or tested | **Pending** |

## 3. Observability: design, validation and limits

Producer metrics include `events_produced_total` and `producer_errors_total`. Processor metrics include `events_processed_total`, `mongodb_inserts_total`, `processing_errors_total`, `http_requests_total`, and `http_request_duration_seconds` (histogram). These names were verified directly in `producer.py` and `processor.py`. Kafka Exporter supplies consumer lag separately.

The monitoring releases were `monitoring` (kube-prometheus-stack 92.21.1), `loki` (7.5.0), `alloy` (1.15.0), and `kafka-exporter` (4.1.1). Dashboards, Prometheus targets, Loki logs and correlation evidence are captured in screenshots 07–16d. A single zero-lag measurement does not establish permanent absence of backlog, and dashboard screenshots do not constitute a long-term availability test.

## 4. Autoscaling: method and interpretation

**Method:** A two-minute CPU-bound Python loop ran inside the producer container. `kubectl get hpa producer-hpa -n ca2 -w` showed utilization at `251%/50%` with three replicas, then `83%/50%`, then approximately `2%/50%` as load ended. Scale-down proceeded from three to two, and the final HPA/Deployment status showed one replica. This is direct evidence of automatic **scale-up and scale-down**, correcting the specific CA2 deficiency. The processor HPA was also active after recovery.

**Limitations:** This experiment stresses CPU rather than measuring sustained production throughput, p95 processing latency under load, or cluster-wide capacity. Replicas can increase production rate and may affect event volume; they do not automatically establish improved end-to-end service-level objectives.

## 5. Security: what was actually demonstrated

- **Kafka TLS:** broker advertised SSL on 9094; controller listener 9093. Application TLS configuration was inspected and publishing continued.
- **MongoDB TLS:** `mongod` was observed with `requireTLS`, certificate/key and CA paths. TLS backup succeeded using the certificate-valid Kubernetes hostname.
- **Network isolation:** five ingress policies plus two egress policies were active. Explicit new TCP connection tests found producer → Kafka allowed, producer → MongoDB timed out, and processor → MongoDB allowed. This is stronger than inferring isolation from YAML alone.
- **EKS enforcement:** AWS VPC CNI add-on configuration reported enabled NetworkPolicy and `standard` mode. The latter may permit traffic briefly before policies are installed for a new Pod.
- **Secrets:** `CA3/security/tls/` and `CA3/security/backups/` are Git-ignored; private files and database archives must stay local. The upstream Kafka Exporter Helm values had no populated SASL SCRAM password. These checks are **not** a complete repository-wide credential audit.
- **RBAC:** CA2 least-privilege design and instructor feedback informed the CA3 deployment plan. The CA3 fresh-deployment order and RBAC verification remain to be demonstrated before claiming fully tested reproducibility.

## 6. Resilience: experiment record

**Producer:** deleting the producer Pod triggered replacement through its Deployment. The replacement resumed Kafka publication; the processor continued storing events. Evidence: screenshot 29.

**Processor:** the processor Pod was replaced and event processing resumed. Evidence: screenshot 30 (and 30a).

**Kafka:** before a planned shutdown, producer and processor were scaled to zero and the processor HPA temporarily removed. Kafka was stopped, the EBS volume became available, and a stopped-broker snapshot was created. Kafka was scaled back to one, then the processor and producer were restored, and the processor HPA was re-applied. The original PVC stayed bound, TLS listener configuration remained present, and consumer lag returned to zero. Evidence: screenshot 31 and command output. **No EBS snapshot restoration was performed.**

**MongoDB:** a TLS-authenticated `mongodump` was taken before the Pod deletion. The MongoDB StatefulSet recreated the Pod, its existing PVC remained bound, the processor resumed writes, and Kafka lag remained zero. Evidence: screenshot 32 and command output. **No archive restoration was performed.**

**Video:** [CA3 Resilience Drill Demonstration (unlisted YouTube)](https://youtu.be/aF8TDq8XbP0). The author reported that it is unlisted; confirm signed-out access and the assignment's maximum duration before submission. The link's contents/duration have not been independently inspected in this packet.

## 7. Automated REST verification

The source implements `GET /health`, `GET /events`, `GET /alerts`, and `GET /metrics`. `scripts/verify-rest.sh` starts a temporary port-forward, performs requests, checks health JSON fields, verifies events/alerts are JSON arrays, checks metric families, and cleans up. Live execution returned:

```text
PASS: /health returns healthy MongoDB and Kafka topic status
PASS: /events returns a JSON array (100 events)
PASS: /alerts returns a JSON array (100 alerts)
PASS: /metrics exposes REST and MongoDB metrics
SUCCESS: All four CA3 REST endpoint checks passed
```

This specifically addresses the CA2 instructor's concern that the previous smoke test merely printed manual commands. It does not verify all response records or negative/error paths.

## 8. Problems encountered, corrections and AI guidance

| Problem / initial suggestion | Observation | Correction / verification |
|---|---|---|
| `mongodump --tls` suggested | Installed tool returned `unknown option tls` | Inspected `mongodump --help`, used `--ssl` and `--sslCAFile` |
| MongoDB backup targeted `localhost` | X.509 hostname validation failed: certificate SANs did not include `localhost` | Used `mongodb.ca2.svc.cluster.local`, preserving CA and hostname validation; dump succeeded |
| Initial Kafka EBS snapshot was live | Application-consistent recovery point not established | Stopped Kafka before creating completed snapshot; still did **not** claim tested restoration |
| Temporary Kafka TLS test NetworkPolicy remained | Extra access allowed for pods labeled `app=kafka-tls-test` | Backed up and deleted test policy; five ingress rules remained |
| HPA temporarily removed for Kafka drill | Processor HPA initially reported unknown CPU on re-creation | Waited for metrics; confirmed `3%/50%`, `ScalingActive=True` |
| Egress policy behavior assumed from YAML | Policy existence alone insufficient | Applied producer/processor egress rules; checked logs, lag and explicit allowed/blocked TCP paths |
| Pause/resume scripts initially drafted | `bash -n` cannot validate controller reconciliation or safe recovery | Added early `SAFETY STOP` guards; tested guard output; **did not** claim successful pause/resume |
| CA2 automatic scale-up missing | CA2 instructor deducted points | Performed CA3 sustained CPU-load HPA test; observed 1→3 scale-up and later scale-down |
| CA2 REST smoke test manual | CA2 instructor deducted points | Created and live-tested `verify-rest.sh` against four routes |

AI assistance was used for explanations, commands, manifest drafts, troubleshooting, test design and documentation. Suggestions were **not treated as proof**. Command output, application logs, actual REST responses, HPA observations, AWS responses and screenshots determined whether claims were accepted, revised or left pending.

## 9. Reproducibility and operational status

| Workflow | State at documentation time |
|---|---|
| `scripts/status.sh` | Runtime tested; screenshot 37 |
| `scripts/verify-rest.sh` | Runtime tested; screenshot 38 |
| `scripts/pause.sh` | Syntax checked, safety guard tested; **not operationally tested** |
| `scripts/resume.sh` | Syntax checked, safety guard tested; **not operationally tested** |
| `scripts/create.sh` | **Not yet implemented/tested** |
| `scripts/teardown.sh` | **Not yet implemented/tested** |

A clean deployment must create RBAC/ServiceAccounts before dependent Deployments and must test the full sequence, including TLS, monitoring, storage and REST health. The CA2 instructor explicitly flagged this ordering. Do not describe CA3 as a verified one-command clean rebuild until the create/teardown cycle has actually passed.

## 10. Assumptions and known limitations

1. AWS region `us-east-2`, CLI profile `ca2`, cluster `ca3-eks-cluster`, and application namespace `ca2` are used for the observed tests.
2. Kafka uses one broker and MongoDB one StatefulSet replica; there is no demonstrated multi-replica high availability.
3. Five observed EBS PVs use `Retain`; EKS deletion may leave chargeable storage behind.
4. The completed Kafka snapshot and MongoDB backup have **not** been restore-tested.
5. Standard NetworkPolicy enforcement has a potential new-Pod programming window.
6. CPU-driven HPA testing does not establish sustained production throughput or failover behavior.
7. Automated pause/resume and clean create/delete remain incomplete; syntax validation is not runtime verification.
8. The REST smoke test checks basic JSON types and key fields, not all API semantics or error cases.
9. Secret lifecycle and certificate rotation are not demonstrated as production-grade automation.
10. CA3 is AWS-specific; the CA4 multi-cloud problem space will require portability choices around compute, storage, identity and observability.

## 11. Rubric-to-evidence map

| Category | Weight | Main evidence | Qualification |
|---|---:|---|---|
| Observability & Logging | 20% | 07–16d, Prometheus and Loki | Point-in-time dashboards |
| Autoscaling | 15% | 17–19, 33–34 | CPU load, not production benchmark |
| Security Hardening | 15% | 20b–28, 35 | Tested paths; not an exhaustive penetration test |
| Resilience | 25% | 29–32, video | Pod/restart recovery; backup restores untested |
| Documentation & Usability | 10% | README, 37, 38 | Create/pause/resume/teardown still pending |
| Integrity Packet | 15% | This packet | Claims labeled by verification level |

## 12. Official technical references

- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Kubernetes NetworkPolicies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Kubernetes Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Amazon EKS VPC CNI NetworkPolicy](https://docs.aws.amazon.com/eks/latest/userguide/cni-network-policy-configure.html)
- [Amazon EKS EBS CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)
- [Prometheus metric types](https://prometheus.io/docs/concepts/metric_types/)

These are technical reference links, not a claim that every linked page was freshly consulted during this CA3 run.

## 13. Final assessment

CA3 runtime evidence supports a working authentication-event pipeline with Prometheus/Grafana metrics, Loki centralized logs, automatic CPU-driven scaling, TLS-protected Kafka and MongoDB connections, restrictive network paths, and recovery from individual Pod or planned broker interruptions. The Integrity Packet intentionally separates those tested achievements from backup restore, full automation and high-availability claims that remain unverified.


## Automation review update (2026-11-08)

The reviewed scripts `pause.sh`, `resume.sh`, and `teardown.sh` have passed local Bash syntax checks only; **they have not been executed against the live EKS cluster**. `create.sh` intentionally exits during preflight because this archive does not contain a reproducible TLS/Secrets, EBS CSI, RBAC, Services, and ECR bootstrap. It does not provision infrastructure. The teardown script deletes the EKS cluster only after explicit confirmation, retains EBS volumes and snapshots for manual ownership review, and cannot guarantee zero AWS charges. Do not claim a successful delete/recreate round trip. Pause/resume assumes one replica per application workload and depends on the local Kafka Exporter port-forward; monitoring is not deliberately scaled down. Pause/resume is not a validated production procedure.
