# CA0 – Manual Deployment on AWS

## Overview

This assignment implements a manually deployed end-to-end IoT data pipeline using **Amazon Web Services (AWS)**.

The objective is to provision and configure the infrastructure manually, deploy the required services, connect the complete data pipeline, apply basic security controls, and verify successful data flow from producer to database.

### Pipeline

```text
Producer(s)
     │
     ▼
Apache Kafka
     │
     ▼
Processor
     │
     ▼
MongoDB
```

A REST API is also provided for pipeline control and/or data retrieval.

---

## 1. Reference Software Stack

The following reference stack is used for CA0 and will serve as the baseline stack for subsequent course assignments.

| Component         | Technology               | Version     |
| ----------------- | ------------------------ | ----------- |
| Cloud Provider    | AWS                      | N/A         |
| Compute           | Amazon EC2               | N/A         |
| Operating System  | Ubuntu                   | `<version>` |
| Container Runtime | Docker                   | `<version>` |
| Pub/Sub Broker    | Apache Kafka             | `<version>` |
| Database          | MongoDB                  | `<version>` |
| Processor         | `<technology>`           | `<version>` |
| REST API          | `<technology/framework>` | `<version>` |
| Producer          | `<technology>`           | `<version>` |

### Stack Selection Rationale

Briefly explain why these technologies were selected.

Example considerations:

* compatibility between components
* Docker support
* ease of deployment
* documentation/community support
* suitability for IoT workloads
* ability to reuse the stack in future assignments

---

# 2. AWS Environment

## Region

```text
AWS Region: <e.g. us-east-1>
```

## Network Configuration

| Resource          | Name     | Configuration     |
| ----------------- | -------- | ----------------- |
| VPC               | `<name>` | `<CIDR>`          |
| Subnet            | `<name>` | `<CIDR>`          |
| Availability Zone | `<AZ>`   |                   |
| Route Table       | `<name>` | `<configuration>` |
| Internet Gateway  | `<name>` | `<configuration>` |

---

# 3. EC2 Virtual Machines

CA0 uses four EC2 virtual machines.

| Host            | Purpose              | Instance Type | vCPU |  RAM | OS     | Private IP | Public IP  |
| --------------- | -------------------- | ------------- | ---: | ---: | ------ | ---------- | ---------- |
| `ca0-broker`    | Kafka                | `<type>`      |    2 | 4 GB | Ubuntu | `<IP>`     | `<IP/N/A>` |
| `ca0-database`  | MongoDB              | `<type>`      |    2 | 4 GB | Ubuntu | `<IP>`     | `<IP/N/A>` |
| `ca0-processor` | Processor / REST API | `<type>`      |    2 | 4 GB | Ubuntu | `<IP>`     | `<IP/N/A>` |
| `ca0-producer`  | Producer(s)          | `<type>`      |    2 | 4 GB | Ubuntu | `<IP>`     | `<IP/N/A>` |

## EC2 Evidence

Screenshot:

```text
screenshots/01-ec2-instances.png
```

![EC2 Instances](screenshots/01-ec2-instances.png)

---

# 4. Network Architecture

## Network Diagram

```text
                        Internet
                           │
                           │ SSH / REST
                           ▼
                 ┌───────────────────┐
                 │      AWS VPC      │
                 │   <VPC CIDR>      │
                 │                   │
                 │   ┌───────────┐   │
                 │   │ Producer  │   │
                 │   └─────┬─────┘   │
                 │         │         │
                 │         ▼         │
                 │   ┌───────────┐   │
                 │   │   Kafka   │   │
                 │   │   :9092   │   │
                 │   └─────┬─────┘   │
                 │         │         │
                 │         ▼         │
                 │   ┌───────────┐   │
                 │   │ Processor │   │
                 │   │ REST API  │   │
                 │   └─────┬─────┘   │
                 │         │         │
                 │         ▼         │
                 │   ┌───────────┐   │
                 │   │ MongoDB   │   │
                 │   │  :27017   │   │
                 │   └───────────┘   │
                 │                   │
                 └───────────────────┘
```

Final network diagram:

```text
diagrams/network-diagram.png
```

![Network Diagram](diagrams/network-diagram.png)

The final diagram documents:

* VPC and subnet CIDRs
* VM placement
* private/public IP usage
* open ports
* communication paths
* trust boundaries

---

# 5. Security Groups and Firewall Rules

Only ports required by the deployment are permitted.

|     Port | Protocol | Service  | Source     | Purpose                    |
| -------: | -------- | -------- | ---------- | -------------------------- |
|       22 | TCP      | SSH      | `<source>` | Administrative access      |
|     9092 | TCP      | Kafka    | `<source>` | Producer/processor → Kafka |
|    27017 | TCP      | MongoDB  | `<source>` | Processor → MongoDB        |
| `<port>` | TCP      | REST API | `<source>` | API access                 |

## Security Controls

* [ ] SSH key authentication enabled
* [ ] SSH password authentication disabled
* [ ] Kafka restricted to required hosts/network
* [ ] MongoDB restricted to required hosts/network
* [ ] Only necessary inbound ports opened
* [ ] Containers run as non-root where supported
* [ ] AWS credentials are not stored in GitHub
* [ ] SSH private keys are not stored in GitHub

### Security Group Evidence

![Security Groups](screenshots/02-security-groups.png)

---

# 6. Software Installation

## Docker

Docker is installed on the hosts that run containerized services.

### Version

```bash
docker --version
```

Output:

```text
<paste verified output>
```

### Service Status

```bash
sudo systemctl status docker
```

---

# 7. Apache Kafka

Kafka serves as the Pub/Sub message broker.

## Host

```text
Host: ca0-broker
Private IP: <IP>
Port: 9092
```

## Installation

Document the commands or process used to install Kafka.

```bash
# Add verified installation commands here
```

## Kafka Topic

```text
Topic: <topic-name>
```

Create/inspect the topic:

```bash
<verified command>
```

## Kafka Verification

```bash
<verified command>
```

Expected/observed result:

```text
<output>
```

### Evidence

![Kafka Running](screenshots/03-kafka-running.png)

---

# 8. MongoDB

MongoDB stores the processed messages.

## Host

```text
Host: ca0-database
Private IP: <IP>
Port: 27017
```

## Installation

```bash
# Add verified installation commands here
```

## Database Configuration

```text
Database: <database-name>
Collection: <collection-name>
```

## MongoDB Verification

```bash
<verified command>
```

Observed result:

```text
<output>
```

### Evidence

![MongoDB](screenshots/04-mongodb.png)

---

# 9. Producer

The producer simulates or generates IoT data and publishes messages to Kafka.

## Host

```text
Host: ca0-producer
Kafka destination: <broker-private-ip>:9092
Topic: <topic>
```

## Container

```text
Image: <image>
Tag: <tag>
```

Run:

```bash
<verified docker command>
```

## Example Message

```json
{
  "device_id": "<example>",
  "timestamp": "<example>",
  "value": "<example>"
}
```

### Evidence

![Producer](screenshots/05-producer.png)

---

# 10. Processor

The processor consumes messages from Kafka, performs the required transformation/processing, and stores the resulting data in MongoDB.

## Host

```text
Host: ca0-processor
```

## Connections

```text
Kafka:
<broker-private-ip>:9092

MongoDB:
mongodb://<database-private-ip>:27017/<database>
```

## Container

```text
Image: <image>
Tag: <tag>
```

Run:

```bash
<verified docker command>
```

### Evidence

![Processor](screenshots/06-processor.png)

---

# 11. REST API

The processor exposes a documented REST endpoint.

## Endpoint

```text
Method: GET
Endpoint: /<endpoint>
Port: <port>
```

## Request

```bash
curl http://<host>:<port>/<endpoint>
```

## Response

```json
{
  "<example>": "<actual response>"
}
```

### Evidence

![REST API](screenshots/07-rest-api.png)

---

# 12. End-to-End Data Pipeline

The complete pipeline is:

```text
Producer
   │
   │ message
   ▼
Kafka
   │
   │ consume
   ▼
Processor
   │
   │ processed record
   ▼
MongoDB
```

## Test Procedure

### Step 1 – Start Producer

```bash
<command>
```

### Step 2 – Verify Kafka

```bash
<command>
```

### Step 3 – Verify Processor

```bash
<command>
```

### Step 4 – Verify MongoDB

```bash
<command>
```

## Result

Describe what happened during the test.

```text
<actual test result>
```

### End-to-End Evidence

![End-to-End Test](screenshots/08-end-to-end-test.png)

---

# 13. Service Persistence

Required services are configured to start automatically after VM reboot.

| Service   | Host            | Startup Method   | Verified |
| --------- | --------------- | ---------------- | -------- |
| Kafka     | `ca0-broker`    | `<systemd/etc.>` | ✅/❌      |
| MongoDB   | `ca0-database`  | `<systemd/etc.>` | ✅/❌      |
| Processor | `ca0-processor` | `<method>`       | ✅/❌      |
| Producer  | `ca0-producer`  | `<method>`       | ✅/❌      |

Verification commands:

```bash
<commands>
```

---

# 14. Logging

| Component | Log Location |
| --------- | ------------ |
| Kafka     | `<location>` |
| MongoDB   | `<location>` |
| Processor | `<location>` |
| Producer  | `<location>` |

Example:

```bash
<command used to inspect logs>
```

---

# 15. Configuration Summary

| Component | Image / Version | Host            |     Port |
| --------- | --------------- | --------------- | -------: |
| Kafka     | `<version>`     | `ca0-broker`    |     9092 |
| MongoDB   | `<version>`     | `ca0-database`  |    27017 |
| Processor | `<image:tag>`   | `ca0-processor` | `<port>` |
| Producer  | `<image:tag>`   | `ca0-producer`  |      N/A |
| REST API  | `<version>`     | `ca0-processor` | `<port>` |

---

# 16. Repository Structure

```text
CA0/
│
├── README.md
│
├── docs/
│   ├── commands.md
│   ├── configuration.md
│   └── integrity-packet.md
│
├── diagrams/
│   └── network-diagram.png
│
├── screenshots/
│   ├── 01-ec2-instances.png
│   ├── 02-security-groups.png
│   ├── 03-kafka-running.png
│   ├── 04-mongodb.png
│   ├── 05-producer.png
│   ├── 06-processor.png
│   ├── 07-rest-api.png
│   └── 08-end-to-end-test.png
│
├── scripts/
│   └── ...
│
├── producer/
│   └── ...
│
└── processor/
    └── ...
```

---

# 17. Deviations / Issues Encountered

Document any deviations from the original reference stack.

| Issue / Deviation | Reason     | Solution     |
| ----------------- | ---------- | ------------ |
| `<issue>`         | `<reason>` | `<solution>` |

If there were no deviations:

```text
No significant deviations from the selected reference stack.
```

---

# 18. Integrity Packet

The CA0 Integrity Packet is available at:

[`docs/integrity-packet.md`](docs/integrity-packet.md)

It documents:

* claims made about the deployment
* supporting evidence
* assumptions
* AI-generated guidance used
* guidance accepted/rejected
* validation procedures
* final verification results

---

# 19. Demo Video

A 1–2 minute demonstration shows:

1. Producer generating/publishing data
2. Kafka receiving the messages
3. Processor consuming the messages
4. MongoDB containing the resulting record
5. REST API request and response

**Demo Video:** `<external-video-link>`

---

# 20. Final Verification Checklist

### Infrastructure

* [ ] 3–4 AWS EC2 VMs provisioned
* [ ] Approximately 2 vCPU / 4 GB RAM per VM
* [ ] VM names, IPs, region, subnet and instance types documented

### Pipeline

* [ ] Producer operational
* [ ] Kafka operational
* [ ] Processor operational
* [ ] MongoDB operational
* [ ] Producer → Kafka verified
* [ ] Kafka → Processor verified
* [ ] Processor → MongoDB verified

### REST API

* [ ] REST endpoint documented
* [ ] Successful request demonstrated
* [ ] Successful response captured

### Security

* [ ] SSH keys only
* [ ] Password SSH disabled
* [ ] Minimal inbound ports
* [ ] Non-root containers where supported

### Documentation

* [ ] README complete
* [ ] Configuration summary complete
* [ ] Network diagram complete
* [ ] Screenshots included
* [ ] Software versions documented
* [ ] Commands/instructions documented
* [ ] Deviations documented

### Submission

* [ ] Integrity Packet complete
* [ ] End-to-end evidence captured
* [ ] Demo video recorded
* [ ] Demo video link added
* [ ] Repository pushed to GitHub

---

## AI Assistance

AI assistance was used where applicable for technical guidance, troubleshooting, and documentation support. AI-generated recommendations were validated against the actual AWS deployment, command output, service logs, official documentation, and end-to-end testing.

Detailed AI usage and validation are documented in the **Integrity Packet**.
