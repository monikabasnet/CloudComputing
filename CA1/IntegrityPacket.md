# CA1 Integrity Packet

## Purpose

This Integrity Packet records the major claims made by the CA1 Infrastructure as Code deployment, the evidence used to verify those claims, the assumptions under which the automation operates, and the review of AI-assisted work used during implementation and troubleshooting.

The evidence referenced below is stored in the `evidence/` directory and can be opened directly through the provided links.

---

## 1. Automation Claims and Evidence

### Claim 1 – AWS infrastructure is provisioned through Terraform

The CA1 AWS infrastructure is defined through Terraform rather than being created manually.

The Terraform configuration defines networking, security groups, EC2 instances, variables, and deployment outputs.

**Verification performed:**

- Terraform configuration validation was completed successfully.
- A Terraform execution plan was reviewed.
- Terraform apply completed successfully.
- Four EC2 instances were observed after provisioning.

**Evidence:**

- [Terraform validation](evidence/04-terraform-validate.png)
- [Terraform plan](evidence/05-terraform-plan.png)
- [Terraform apply success](evidence/06-terraform-apply-success.png)
- [Four EC2 instances](evidence/07-four-ec2-instances.png)

---

### Claim 2 – Network and security configuration is defined as code

VPC, subnet, routing, and security-group configuration are managed through Terraform.

Service-specific network rules are used for Kafka, MongoDB, and the Processor REST API.

**Verification performed:**

The deployed AWS security-group configuration was inspected after Terraform provisioning.

**Evidence:**

- [Kafka security group](evidence/08-security-group-kafka.png)
- [MongoDB security group](evidence/09-security-group-mongodb.png)
- [Processor security group](evidence/10-security-group-processor.png)

---

### Claim 3 – Configuration management is automated with Ansible

Operating-system dependencies, Docker, MongoDB, Kafka, the Processor, and the Producer are configured through Ansible roles.

**Verification performed:**

Ansible connectivity was tested against all four EC2 instances. The complete playbook was then executed successfully with no unreachable or failed hosts.

**Evidence:**

- [Ansible connectivity](evidence/12-ansible-connectivity.png)
- [Ansible base provisioning](evidence/13-ansible-base-provisioning.png)
- [MongoDB deployment](evidence/15-mongodb-ansible-deployment.png)
- [Kafka deployment](evidence/16-kafka-ansible-deployment.png)
- [Ansible playbook recap](evidence/20-ansible-playbook-recap.png)

---

### Claim 4 – Secrets are not stored as plaintext application configuration

MongoDB credentials are maintained in an encrypted Ansible Vault file.

Terraform state, Terraform plans, local variable files, generated inventory, private keys, and Vault password files are excluded from Git through `.gitignore`.

**Verification performed:**

The Ansible Vault header was checked without exposing the encrypted credential contents. Git ignore rules were also checked against sensitive and generated files.

**Evidence:**

- [Encrypted Ansible Vault](evidence/11-ansible-vault-encrypted.png)
- [Secret and repository hygiene](evidence/29-secret-and-repository-hygiene.png)

---

### Claim 5 – Deployment configuration is parameterized

Environment-specific infrastructure settings are exposed as Terraform variables.

Examples include the AWS region, instance type, network ranges, service ports, Kafka topic, container image tags, administrator CIDR, and SSH public-key path.

Example override values are supplied through `terraform/terraform.tfvars.example`.

**Verification performed:**

Terraform variable declarations and the corresponding example override values were inspected.

**Evidence:**

- [Terraform parameterization](evidence/30-terraform-parameterization.png)

---

### Claim 6 – Kafka is deployed and operational

Apache Kafka 4.3.1 is deployed using KRaft mode and the `auth-events` topic is available.

**Verification performed:**

The Kafka installation, topic, and systemd service were checked after deployment.

**Evidence:**

- [Kafka Ansible deployment](evidence/16-kafka-ansible-deployment.png)
- [Kafka verification](evidence/17-kafka-verification.png)

---

### Claim 7 – MongoDB is deployed with authentication

MongoDB 8.0.29 is deployed as a Docker container and authentication is enabled.

The application database is `threat_monitor`, and processed events are stored in the `security_events` collection.

**Verification performed:**

MongoDB authentication was verified through the Ansible role. Processed security events were also queried directly from the database.

**Evidence:**

- [MongoDB Ansible deployment](evidence/15-mongodb-ansible-deployment.png)
- [MongoDB security events](evidence/26-mongodb-security-events.png)

---

### Claim 8 – Authentication events are published to Kafka

The Producer publishes JSON authentication events to the Kafka `auth-events` topic.

**Verification performed:**

A Producer event was published successfully and Kafka returned the topic, partition, and offset.

**Evidence:**

- [Producer event and play recap](evidence/23-producer-event-and-play-recap.png)

---

### Claim 9 – The complete processing pipeline works end to end

The deployed pipeline operates as:

```text
Producer
   |
   v
Kafka
   |
   v
Processor
   |
   v
MongoDB
   |
   v
REST API
```

The Processor consumes authentication events, adds classification information, stores the enriched event in MongoDB, and exposes stored events through the REST API.

**Verification performed:**

Events retrieved through the REST API contained the original event information together with Processor-generated `failed_attempts` and `status` fields.

**Evidence:**

- [End-to-end event processing](evidence/24-end-to-end-event-processing.png)
- [MongoDB persistence](evidence/26-mongodb-security-events.png)

---

### Claim 10 – Threat detection identifies repeated failed authentication attempts

Repeated failed authentication attempts for the same username and source IP are classified according to the configured thresholds.

```text
1–2 failures -> FAILED_LOGIN
3–4 failures -> SUSPICIOUS
5+ failures  -> POSSIBLE_BRUTE_FORCE
```

**Verification performed:**

Repeated failed events were generated for the same username/source-IP pair. The `/alerts` endpoint showed progression through `SUSPICIOUS` to `POSSIBLE_BRUTE_FORCE`.

**Evidence:**

- [Brute-force detection](evidence/25-brute-force-detection.png)

---

### Claim 11 – Pipeline validation is automated

A validation script is provided at:

```text
scripts/validate.sh
```

The script performs connectivity checking, REST API health checking, event publication, and retrieval of processed events.

**Verification performed:**

The complete validation script was executed successfully and ended with:

```text
=== CA1 pipeline validation completed successfully ===
```

**Evidence:**

- [Automated pipeline validation](evidence/28-automated-pipeline-validation.png)

---

### Claim 12 – Ansible configuration is idempotent

Repeated Ansible execution does not unnecessarily modify services that are already in the desired configuration.

**Verification performed:**

The complete playbook was executed after the infrastructure had already been configured.

The final recap reported:

```text
changed=0
failed=0
```

for Kafka, MongoDB, Processor, and Producer configuration.

**Evidence:**

- [Base Ansible idempotency](evidence/14-ansible-idempotency-base.png)
- [Complete Ansible idempotency](evidence/27-ansible-idempotency.png)

---

### Claim 13 – Deployment outputs are exposed through Terraform

Terraform outputs provide the addresses and identifiers required to operate and validate the environment.

Outputs include:

```text
Producer public/private IP
Kafka public/private IP
Kafka bootstrap server
Kafka topic
Processor public/private IP
REST API base URL
MongoDB public/private IP
MongoDB connection target
MongoDB database
MongoDB collection
VPC ID
Subnet ID
```

Credentials are not exposed through Terraform outputs.

**Verification performed:**

The deployed Terraform outputs were inspected after successful provisioning.

**Evidence:**

- [Terraform outputs summary](evidence/31-terraform-outputs-summary.png)

---

## 2. Assumptions

The automation was developed and validated under the following assumptions.

### AWS Region

The default deployment region is:

```text
us-east-2
```

AMI identifiers are region-specific. A MongoDB AMI value used by the configuration is therefore associated with the configured region.

### AWS Permissions

It is assumed that the AWS identity running Terraform has permission to create, inspect, modify, and delete the AWS resources defined by the Terraform configuration.

### Administrative Network

It is assumed that the public IPv4 address of the deployment workstation is supplied as a `/32` value through `admin_cidr`.

### SSH Key

The default SSH public-key location is assumed to be:

```text
~/.ssh/ca1-key.pub
```

A different path can be supplied through Terraform variables.

### Ansible Vault

It is assumed that the person performing the deployment has access to the correct Ansible Vault password.

The Vault password is not stored in the repository.

### Single-Node Kafka

Kafka is intentionally deployed as a single combined KRaft broker/controller.

High availability and broker redundancy are therefore outside the scope of this deployment.

### Single-Node MongoDB

MongoDB is intentionally deployed as one database instance rather than as a replica set.

Database failover and replication are outside the scope of CA1.

### Terraform State

Terraform state is stored locally for this assignment and is excluded from version control.

A remote state backend is not used.

### Public IP Addresses

Public EC2 addresses may change after infrastructure recreation.

The Ansible inventory is therefore generated from current Terraform outputs instead of relying on permanently hard-coded addresses.

---

## 3. Validation and Troubleshooting Record

### Kafka Consumer-Group Failure

During end-to-end validation, the Producer was confirmed to be publishing events to Kafka, but the Processor initially did not consume the published event.

Several layers were checked rather than assuming that event publication implied successful processing.

The following checks were performed:

1. Processor REST health was verified.
2. Processor logs were inspected.
3. TCP connectivity from the Processor container to Kafka port `9092` was verified.
4. Kafka listener and advertised-listener configuration was inspected.
5. Kafka consumer-group state was queried.
6. Kafka service logs were inspected.

The Kafka logs showed:

```text
INVALID_REPLICATION_FACTOR
```

for the `__consumer_offsets` internal topic.

Kafka was attempting to use a replication factor of three even though only one broker was deployed.

The Ansible-managed Kafka configuration was revised to include:

```text
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
```

After the configuration was applied and Kafka was restarted, the Processor consumer group was successfully observed with:

```text
CURRENT-OFFSET = LOG-END-OFFSET
LAG = 0
```

A new Producer event was then generated and was successfully observed through the Processor REST API and MongoDB.

This troubleshooting process was used to verify the actual cause rather than treating successful TCP connectivity as proof that Kafka consumer-group operation was correct.

---

## 4. AI-Assisted Work and Review

AI assistance was used during selected implementation, documentation, and troubleshooting activities.

AI-generated suggestions were not treated as proof that the deployment was correct. Commands and configuration changes were reviewed and their effects were verified against the running environment.

### Areas Where AI Assistance Was Used

Assistance was used for:

- Terraform and Ansible structure review
- Ansible role development
- Producer and Processor deployment configuration
- Docker deployment configuration
- shell automation structure
- Kafka troubleshooting
- validation-command construction
- README organization
- Integrity Packet organization

### Review Process

Suggested changes were evaluated through one or more of the following methods:

- Terraform validation
- Terraform plan inspection
- Ansible syntax checking
- Ansible execution
- repeated Ansible execution
- service status inspection
- Docker logs
- Kafka service logs
- Kafka consumer-group inspection
- direct TCP connectivity tests
- MongoDB queries
- REST API requests
- end-to-end pipeline testing

Suggestions that did not match observed system behavior were revised rather than being accepted without verification.

### Example of AI Suggestion Requiring Revision

During Kafka troubleshooting, initial investigation focused on network connectivity and Kafka listener configuration.

TCP connectivity to Kafka was successfully verified, but event consumption still failed.

Kafka service logs were subsequently inspected and showed that the actual failure was caused by the internal `__consumer_offsets` topic attempting to use a replication factor of three on a single-broker deployment.

The Kafka Ansible configuration was then revised for single-node replication, after which consumer-group operation and end-to-end processing were verified.

This demonstrated that the initial diagnostic direction was insufficient and that the final configuration was based on observed Kafka evidence rather than an unverified suggestion.

### Example of Command Review

A complex diagnostic command used during Kafka troubleshooting produced a quoting error and an invalid hostname.

That command was discarded rather than being treated as evidence of a Kafka failure.

A simpler sequence of commands was used instead:

1. The Kafka private IP was retrieved.
2. TCP connectivity was tested directly.
3. Kafka configuration was inspected.
4. Consumer-group behavior was checked.
5. Kafka logs were inspected.

The simpler tests produced evidence that could be interpreted independently.

---

## 5. Security Review

Several security controls were checked as part of the CA1 implementation.

### Secret Storage

MongoDB credentials are maintained in an encrypted Ansible Vault file.

### Repository Exclusions

The following local or sensitive artifacts are excluded from Git:

```text
Terraform state
Terraform plans
terraform.tfvars
*.auto.tfvars
SSH/private keys
environment files
Vault password files
generated inventory
runtime logs
```

### Terraform Outputs

Credentials are not exposed through Terraform outputs.

MongoDB connection information contains the internal host and port rather than embedded authentication credentials.

### SSH Access

Administrative SSH access is controlled through the configurable `admin_cidr` value.

---

## 6. Evidence Summary

### Terraform and AWS

- [Project structure](evidence/02-ca1-project-structure.png)
- [IAM Terraform policy](evidence/03-iam-terraform-policy.png)
- [Terraform validation](evidence/04-terraform-validate.png)
- [Terraform plan](evidence/05-terraform-plan.png)
- [Terraform apply](evidence/06-terraform-apply-success.png)
- [Four EC2 instances](evidence/07-four-ec2-instances.png)
- [Kafka security group](evidence/08-security-group-kafka.png)
- [MongoDB security group](evidence/09-security-group-mongodb.png)
- [Processor security group](evidence/10-security-group-processor.png)

### Ansible and Services

- [Ansible Vault encryption](evidence/11-ansible-vault-encrypted.png)
- [Ansible connectivity](evidence/12-ansible-connectivity.png)
- [Base provisioning](evidence/13-ansible-base-provisioning.png)
- [Base idempotency](evidence/14-ansible-idempotency-base.png)
- [MongoDB deployment](evidence/15-mongodb-ansible-deployment.png)
- [Kafka deployment](evidence/16-kafka-ansible-deployment.png)
- [Kafka verification](evidence/17-kafka-verification.png)
- [Ansible base configuration](evidence/18-ansible-base-configuration.png)
- [Service deployment](evidence/19-ansible-services-deployment.png)
- [Successful playbook recap](evidence/20-ansible-playbook-recap.png)
- [Processor deployment](evidence/21-processor-ansible-deployment.png)
- [REST/security verification](evidence/22-processor-rest-security-verification.png)
- [Producer publication](evidence/23-producer-event-and-play-recap.png)

### Pipeline Validation

- [End-to-end processing](evidence/24-end-to-end-event-processing.png)
- [Brute-force detection](evidence/25-brute-force-detection.png)
- [MongoDB persistence](evidence/26-mongodb-security-events.png)
- [Complete Ansible idempotency](evidence/27-ansible-idempotency.png)
- [Automated pipeline validation](evidence/28-automated-pipeline-validation.png)

### Security, Parameters, and Outputs

- [Secret and repository hygiene](evidence/29-secret-and-repository-hygiene.png)
- [Terraform parameterization](evidence/30-terraform-parameterization.png)
- [Terraform outputs](evidence/31-terraform-outputs-summary.png)

---

## 7. Integrity Statement

The claims in this packet are based on configuration files, command output, service logs, database queries, REST API responses, and screenshots captured from the deployed CA1 environment.

Successful command execution was not treated as sufficient evidence when additional runtime behavior needed to be verified.

Where failures occurred, the observed error output was investigated and configuration changes were tested against the deployed environment.

AI assistance was used as a development and troubleshooting aid. Suggested changes were reviewed, tested, and revised when required. Final claims were based on observed deployment behavior and recorded evidence rather than on AI-generated statements alone.