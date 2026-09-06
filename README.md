# CA0 – Manual IoT Pipeline Deployment on AWS

## Overview

CA0 is a manually deployed end-to-end IoT data pipeline hosted on Amazon Web Services (AWS).

The purpose of this assignment is to provision and configure the infrastructure manually, deploy each required software component, connect the complete data pipeline, apply basic security controls, and verify successful data flow from the producer through the message broker and processor into the database.

The planned pipeline is:

```text
Producer(s)
     |
     | publishes IoT messages
     v
Apache Kafka
     |
     | consumer reads messages
     v
Processor
     |
     | processes/transforms data
     v
MongoDB
```

A REST API is also exposed to provide access to stored pipeline data.

The deployment is intentionally performed manually rather than using a higher-level orchestration platform so that the networking, service configuration, security controls, message flow, and dependencies between components can be understood and verified individually.

---

# 1. Reference Software Stack

The following reference stack is used for CA0 and is intended to serve as the baseline stack for subsequent course assignments.

| Component                 | Technology                | Version                    |
| ------------------------- | ------------------------- | -------------------------- |
| Cloud Provider            | Amazon Web Services (AWS) | N/A                        |
| Compute                   | Amazon EC2                | N/A                        |
| Operating System          | Ubuntu 24.04 LTS          | `<verified version>`       |
| Container Runtime         | Docker Engine             | `<verified version>`       |
| Pub/Sub / Message Broker  | Apache Kafka              | `<verified version>`       |
| Kafka Metadata Management | KRaft                     | `<verified configuration>` |
| Database                  | MongoDB Community         | `<verified version>`       |
| Producer                  | Python                    | `<verified version>`       |
| Processor                 | Python                    | `<verified version>`       |
| REST API                  | Flask                     | `<verified version>`       |
| Message Format            | JSON                      | N/A                        |

Exact installed versions, package versions, and container image tags will be recorded after deployment and verified directly from the running systems.

## Stack Selection Rationale

The stack was selected based on the following considerations:

* compatibility between components
* suitability for an IoT-style producer/consumer pipeline
* support for containerized applications
* availability of official documentation
* ability to manually configure and inspect each component
* ability to reuse the stack in later course assignments
* compatibility with AWS infrastructure
* cost considerations related to the AWS Free Tier

Apache Kafka is used as the message bus because the assignment focuses on Pub/Sub messaging and Kafka provides a clear producer → broker → consumer architecture.

MongoDB is used as the persistent database because processed IoT records can be represented naturally as JSON-like documents.

Python is used for the producer and processor because it allows the application logic to remain relatively small while interacting with Kafka, MongoDB, and HTTP services.

Docker is used for the producer and processor so their dependencies and runtime environments can be packaged reproducibly.

---

# 2. Architecture Decisions and Trade-offs

This section records the major design decisions made during CA0.

For each decision, the selected approach, alternatives, rationale, trade-offs, and eventual validation are documented.

## Decision 1 – Cloud Provider

**Selected:** Amazon Web Services (AWS)

**Alternatives considered:**

* Microsoft Azure
* Google Cloud Platform
* local/on-premises virtual machines

**Rationale:**

AWS provides EC2 virtual machines, VPC networking, Security Groups, SSH-based administration, and the infrastructure required to manually deploy the pipeline.

AWS also allows the deployment to demonstrate cloud-specific networking and security concepts rather than running every component locally.

The deployment will be designed with the AWS Free Tier and available account credits/allowances in mind to minimize unnecessary cost.

**Trade-offs:**

Using AWS introduces provider-specific concepts such as VPCs, subnets, Security Groups, EC2 instance types, and AWS billing.

The Free Tier may also constrain VM sizes or runtime duration, requiring a balance between the assignment's recommended resources and cost.

**Validation:**

`<Complete after deployment.>`

---

## Decision 2 – VM Architecture

**Selected:** Four logically separated EC2 virtual machines, subject to final AWS Free Tier/cost verification.

Planned roles:

```text
ca0-producer
ca0-broker
ca0-processor
ca0-database
```

**Alternatives considered:**

* three VMs with multiple services sharing a host
* four VMs with one primary pipeline role per VM
* running all services on fewer machines

**Rationale:**

A four-VM architecture gives the main pipeline stages clear responsibilities:

```text
Producer VM → Kafka VM → Processor VM → Database VM
```

Separating the components makes network communication, firewall rules, service dependencies, and failure boundaries easier to observe and document.

**Trade-offs:**

Four VMs consume more cloud resources than consolidating services onto fewer machines.

The final instance sizes will therefore be selected only after checking the AWS Free Tier available to the account.

**Validation:**

`<Complete after deployment.>`

---

## Decision 3 – Operating System

**Selected:** Ubuntu 24.04 LTS

**Alternatives considered:**

* Ubuntu 22.04 LTS
* Amazon Linux

**Rationale:**

Ubuntu LTS provides a commonly used Linux server environment with broad documentation and support for the software planned for the pipeline.

Using the same operating system across the VMs also reduces unnecessary differences between hosts.

**Trade-offs:**

Amazon Linux would provide tighter integration with the AWS ecosystem. Ubuntu was selected instead to provide a widely documented Linux environment that is portable beyond AWS.

**Validation:**

`<Record actual AMI and OS information after EC2 creation.>`

---

## Decision 4 – Message Broker

**Selected:** Apache Kafka

**Alternatives considered:**

* RabbitMQ
* MQTT/Mosquitto
* other Pub/Sub systems

**Rationale:**

Kafka directly supports the producer → broker → consumer messaging pattern studied in the course.

The deployment provides practical experience with Kafka topics, producers, consumers, message retention, and consumer processing.

**Trade-offs:**

Kafka is more resource-intensive and operationally complex than lightweight brokers such as MQTT/Mosquitto.

For a small CA0 workload, a lighter broker could be sufficient. Kafka is selected because learning and demonstrating Kafka's messaging model is valuable for the course reference stack.

**Validation:**

`<Verify by publishing and consuming a test message.>`

---

## Decision 5 – Kafka Metadata Management

**Selected:** KRaft, pending verification against the exact Kafka version deployed.

**Alternative considered:**

* ZooKeeper-based Kafka deployment

**Rationale:**

KRaft provides Kafka's metadata-management mechanism without requiring a separate ZooKeeper deployment.

This reduces the number of independent services required for the CA0 environment.

**Trade-offs:**

Course material may discuss ZooKeeper-based Kafka architectures, so the difference between the reference material and the deployed architecture must be clearly documented.

**Validation:**

`<Record Kafka configuration and verify broker startup.>`

---

## Decision 6 – Database

**Selected:** MongoDB Community

**Alternative considered:**

* CouchDB

**Rationale:**

MongoDB provides document-oriented storage that maps naturally to JSON-like IoT records produced by the processor.

It also allows processed records to be queried easily during end-to-end verification.

**Trade-offs:**

MongoDB introduces another independently managed service and must be configured carefully so that the database is not unnecessarily exposed to the Internet.

**Validation:**

`<Insert and query a test document, followed by an end-to-end processor-generated document.>`

---

## Decision 7 – Container Runtime

**Selected:** Docker Engine

**Alternatives considered:**

* direct host installation
* Podman

**Rationale:**

Docker packages the producer and processor with their runtime dependencies and provides a reproducible execution environment.

**Trade-offs:**

Containers introduce an additional abstraction layer and require container networking, image management, and security configuration.

**Validation:**

`<Verify container images, runtime status, non-root execution, and restart behavior.>`

---

## Decision 8 – Application Language

**Selected:** Python

**Alternatives considered:**

* Java
* Node.js

**Rationale:**

Python allows the producer, Kafka consumer/processor, MongoDB integration, and REST API to be implemented with relatively small applications.

**Trade-offs:**

Java has particularly mature integration with the Kafka ecosystem and may provide greater performance for larger workloads. CA0 prioritizes understandable implementation and deployment over high throughput.

**Validation:**

`<Record Python version and demonstrate successful application execution.>`

---

## Decision 9 – REST Framework

**Selected:** Flask

**Alternative considered:**

* FastAPI

**Rationale:**

The assignment requires at least one documented REST endpoint rather than a large web application. Flask provides enough functionality to implement a small HTTP API without adding unnecessary complexity.

**Trade-offs:**

FastAPI provides additional features such as automatic API documentation and stronger request/response modeling. Those features are not required for the small CA0 endpoint.

**Validation:**

`<Demonstrate successful HTTP request and JSON response.>`

---

## Decision 10 – Private Service Communication

**Selected:** Private VPC networking for communication between pipeline components.

**Alternative considered:**

* communication through public IP addresses

**Rationale:**

Kafka and MongoDB do not need to be exposed to the entire Internet. Internal pipeline communication can use private addresses within the AWS VPC.

**Trade-offs:**

Private networking requires additional understanding of VPC addressing, routing, Security Groups, and service bind/listener configuration.

**Validation:**

`<Verify Producer → Kafka → Processor → MongoDB communication using private addressing.>`

---

# 3. AWS Environment

## Region

```text
AWS Region: <region>
```

### Region Selection Rationale

`<Explain why the selected region was used, considering availability, latency, Free Tier/resource availability, and course requirements.>`

---

## Network Configuration

| Resource          | Name     | Configuration     |
| ----------------- | -------- | ----------------- |
| VPC               | `<name>` | `<CIDR>`          |
| Subnet            | `<name>` | `<CIDR>`          |
| Availability Zone | `<AZ>`   |                   |
| Route Table       | `<name>` | `<configuration>` |
| Internet Gateway  | `<name>` | `<configuration>` |

### Network Design

The EC2 instances are placed inside the CA0 VPC and communicate using private IP addresses where possible.

The network is designed so that only services that require communication with one another are permitted through the associated Security Groups.

---

# 4. EC2 Virtual Machines

The planned deployment uses four EC2 virtual machines.

The exact instance type will be selected after checking the AWS Free Tier available to the account.

| Host            | Purpose              | Instance Type |       vCPU |        RAM | OS     | Private IP | Public IP  |
| --------------- | -------------------- | ------------- | ---------: | ---------: | ------ | ---------- | ---------- |
| `ca0-producer`  | Producer(s)          | `<type>`      | `<actual>` | `<actual>` | Ubuntu | `<IP>`     | `<IP/N/A>` |
| `ca0-broker`    | Kafka                | `<type>`      | `<actual>` | `<actual>` | Ubuntu | `<IP>`     | `<IP/N/A>` |
| `ca0-processor` | Processor / REST API | `<type>`      | `<actual>` | `<actual>` | Ubuntu | `<IP>`     | `<IP/N/A>` |
| `ca0-database`  | MongoDB              | `<type>`      | `<actual>` | `<actual>` | Ubuntu | `<IP>`     | `<IP/N/A>` |

The assignment recommends approximately 2 vCPU and 4 GB RAM per VM. Any difference between that recommendation and the actual EC2 configuration will be documented under **Deviations / Issues Encountered**, including Free Tier/cost considerations.

## EC2 Evidence

```text
screenshots/01-ec2-instances.png
```

![EC2 Instances](screenshots/01-ec2-instances.png)

---

# 5. Network Architecture

## Data Flow

```text
Producer
   |
   | publish
   v
Kafka
   |
   | consume
   v
Processor
   |
   | insert
   v
MongoDB
   ^
   |
REST API
```

## Network Diagram

```text
                           Internet
                              |
                         SSH / REST
                              |
                              v
              +--------------------------------+
              |            AWS VPC             |
              |          <VPC CIDR>            |
              |                                |
              |  +--------------------------+  |
              |  |      <subnet CIDR>       |  |
              |  |                          |  |
              |  |  Producer               |  |
              |  |     |                    |  |
              |  |     | Kafka traffic      |  |
              |  |     v                    |  |
              |  |  Kafka Broker            |  |
              |  |     |                    |  |
              |  |     | Kafka traffic      |  |
              |  |     v                    |  |
              |  |  Processor + REST API    |  |
              |  |     |                    |  |
              |  |     | DB traffic         |  |
              |  |     v                    |  |
              |  |  MongoDB                 |  |
              |  |                          |  |
              |  +--------------------------+  |
              |                                |
              +--------------------------------+
```

Final network diagram:

```text
diagrams/network-diagram.png
```

![Network Diagram](diagrams/network-diagram.png)

The final diagram will document:

* VPC CIDR
* subnet CIDR
* VM placement
* private/public IP usage
* required ports
* communication paths
* Internet boundary
* VPC trust boundary
* Security Group restrictions

---

# 6. Security Groups and Firewall Rules

Only ports required by the deployment will be permitted.

|         Port | Protocol | Service  | Source                    | Purpose                    |
| -----------: | -------- | -------- | ------------------------- | -------------------------- |
|           22 | TCP      | SSH      | `<administrative source>` | Administrative access      |
|         9092 | TCP      | Kafka    | `<required SG/hosts>`     | Producer/Processor → Kafka |
|        27017 | TCP      | MongoDB  | `<processor only>`        | Processor → MongoDB        |
| `<API port>` | TCP      | REST API | `<required source>`       | API access                 |

The final rules will be based on the actual deployed configuration rather than assuming that every service must be publicly accessible.

## Security Design

The deployment follows the principle of least privilege.

Kafka should only accept connections from systems that require Kafka access.

MongoDB should only accept database traffic from the processor or other explicitly required systems.

SSH administrative access should be restricted rather than unnecessarily exposed.

## Security Controls

* [ ] SSH key authentication enabled
* [ ] SSH password authentication disabled
* [ ] SSH private key stored securely
* [ ] Kafka restricted to required hosts/security groups
* [ ] MongoDB restricted to required hosts/security groups
* [ ] Only necessary inbound ports opened
* [ ] Containers run as non-root where supported
* [ ] AWS credentials are not stored in GitHub
* [ ] SSH private keys are not stored in GitHub
* [ ] No application secrets committed to Git

## Security Group Evidence

![Security Groups](screenshots/02-security-groups.png)

---

# 7. Software Installation

## Docker

Docker is installed on hosts that run containerized services.

### Version

```bash
docker --version
```

Observed output:

```text
<verified output>
```

### Service Status

```bash
sudo systemctl status docker
```

### Startup Configuration

```text
<document how Docker starts automatically>
```

### Container Security

```text
<document non-root container configuration and verification>
```

---

# 8. Apache Kafka

Kafka serves as the Pub/Sub message broker/message bus.

## Host

```text
Host: ca0-broker
Private IP: <IP>
Kafka Port: 9092
```

## Kafka Architecture

```text
Producer
   |
   | publishes
   v
Kafka Broker
   |
   | Topic: <topic>
   v
Processor / Consumer
```

## Installation

```bash
# Add only commands actually executed and verified.
```

## Metadata Management

```text
Mode: <KRaft / actual mode>
```

Document the reason for the selected mode and the configuration used.

## Kafka Topic

```text
Topic: sensor-data
```

Create/inspect the topic:

```bash
<verified command>
```

## Kafka Verification

A standalone Kafka test will be performed before integrating the producer and processor.

Test message:

```text
hello-ca0
```

Verification command:

```bash
<verified command>
```

Observed result:

```text
<actual output>
```

## Evidence

![Kafka Running](screenshots/03-kafka-running.png)

---

# 9. MongoDB

MongoDB stores records produced by the processor.

## Host

```text
Host: ca0-database
Private IP: <IP>
Port: 27017
```

## Installation

```bash
# Add only commands actually executed and verified.
```

## Database Configuration

```text
Database: ca0
Collection: readings
```

Names may be changed during implementation and will be updated to match the actual deployment.

## Standalone Verification

Before connecting the processor, MongoDB will be tested independently.

Example verification sequence:

```text
Connect
   ↓
Insert test document
   ↓
Query test document
   ↓
Verify result
```

Commands:

```bash
<verified commands>
```

Observed result:

```text
<actual output>
```

## Evidence

![MongoDB](screenshots/04-mongodb.png)

---

# 10. Producer

The producer simulates IoT devices and publishes sensor messages to Kafka.

## Host

```text
Host: ca0-producer

Kafka destination:
<broker-private-ip>:9092

Topic:
sensor-data
```

## Container

```text
Image: <image>
Tag: <tag>
Container user: <user/UID>
```

Build/run:

```bash
<verified Docker commands>
```

## Producer Behavior

The producer will:

1. generate simulated sensor data
2. create a message identifier
3. add a timestamp
4. serialize the message as JSON
5. publish the message to the Kafka topic
6. log the published message

## Message Schema

Example:

```json
{
  "message_id": "<unique-id>",
  "device_id": "sensor-01",
  "timestamp": "<timestamp>",
  "temperature": 85
}
```

The final schema will reflect the implemented producer.

## Evidence

![Producer](screenshots/05-producer.png)

---

# 11. Processor

The processor consumes messages from Kafka, performs a transformation, and stores the resulting records in MongoDB.

## Host

```text
Host: ca0-processor
```

## Connections

Kafka:

```text
<broker-private-ip>:9092
```

MongoDB:

```text
mongodb://<database-private-ip>:27017/<database>
```

## Container

```text
Image: <image>
Tag: <tag>
Container user: <user/UID>
```

Run:

```bash
<verified Docker command>
```

## Processor Behavior

```text
Receive Kafka message
        |
        v
Deserialize JSON
        |
        v
Perform transformation
        |
        v
Create processed record
        |
        v
Insert into MongoDB
        |
        v
Log successful processing
        |
        v
Wait for next message
```

Example transformation:

```text
Input:
temperature = 95

Processed result:
status = HOT
```

The exact transformation used in the final deployment will be documented here.

## Evidence

![Processor](screenshots/06-processor.png)

---

# 12. REST API

The processor host exposes at least one documented REST endpoint for pipeline data retrieval or control.

## Framework

```text
Framework: Flask
Version: <verified version>
```

## Endpoint

```text
Method: GET
Endpoint: /readings
Port: <port>
```

## Purpose

The endpoint retrieves processed sensor records without requiring the client to directly access MongoDB.

Conceptually:

```text
Client
   |
   | GET /readings
   v
REST API
   |
   | query
   v
MongoDB
   |
   | records
   v
REST API
   |
   | JSON
   v
Client
```

## Request

```bash
curl http://<host>:<port>/readings
```

## Response

```json
{
  "<replace>": "<actual verified response>"
}
```

## Evidence

![REST API](screenshots/07-rest-api.png)

---

# 13. End-to-End Data Pipeline

The complete deployed pipeline is:

```text
Producer Container
       |
       | JSON message
       v
Kafka Broker
       |
       | sensor-data topic
       v
Processor Container
       |
       | processed document
       v
MongoDB
```

The REST API provides a separate retrieval path:

```text
Client → REST API → MongoDB → REST API → Client
```

## End-to-End Test Procedure

### Step 1 – Establish Initial State

Record the initial database state.

```bash
<command>
```

### Step 2 – Start/Observe Producer

```bash
<command>
```

Record the generated `message_id`.

### Step 3 – Verify Kafka

```bash
<command>
```

Verify that the expected message is present/consumed.

### Step 4 – Verify Processor

```bash
<command>
```

Verify that the processor received the same `message_id`.

### Step 5 – Verify MongoDB

```bash
<command>
```

Verify that MongoDB contains the processed record with the corresponding `message_id`.

### Step 6 – Verify REST API

```bash
curl http://<host>:<port>/readings
```

Verify that the expected stored record can be retrieved.

## Result

```text
<Describe the actual observed end-to-end result.>
```

## End-to-End Evidence

![End-to-End Test](screenshots/08-end-to-end-test.png)

---

# 14. Service Persistence

Required services are configured to start automatically after VM reboot.

| Service   | Host            | Startup Method   | Verified |
| --------- | --------------- | ---------------- | -------- |
| Kafka     | `ca0-broker`    | `<systemd/etc.>` | ⬜        |
| MongoDB   | `ca0-database`  | `<systemd/etc.>` | ⬜        |
| Processor | `ca0-processor` | `<method>`       | ⬜        |
| Producer  | `ca0-producer`  | `<method>`       | ⬜        |

## Reboot Verification

For each required host:

```text
1. Verify service is running
2. Reboot VM
3. Reconnect
4. Verify service restarted
5. Run pipeline test
```

Commands:

```bash
<verified commands>
```

Observed result:

```text
<actual result>
```

---

# 15. Logging

Each component has a known method/location for retrieving logs.

| Component | Log Location / Command |
| --------- | ---------------------- |
| Kafka     | `<location/command>`   |
| MongoDB   | `<location/command>`   |
| Processor | `<location/command>`   |
| Producer  | `<location/command>`   |
| REST API  | `<location/command>`   |

Example:

```bash
<command used to inspect logs>
```

Logs used as evidence will avoid exposing credentials or private keys.

---

# 16. Configuration Summary

| Component | Image / Version   | Host            |     Port |
| --------- | ----------------- | --------------- | -------: |
| Kafka     | `<version>`       | `ca0-broker`    |     9092 |
| MongoDB   | `<version>`       | `ca0-database`  |    27017 |
| Processor | `<image:tag>`     | `ca0-processor` |      N/A |
| Producer  | `<image:tag>`     | `ca0-producer`  |      N/A |
| REST API  | `<version/image>` | `ca0-processor` | `<port>` |

---

# 17. Repository Structure

```text
CA0/
|
├── README.md
|
├── docs/
│   ├── commands.md
│   ├── configuration.md
│   └── integrity-packet.md
|
├── diagrams/
│   └── network-diagram.png
|
├── screenshots/
│   ├── 01-ec2-instances.png
│   ├── 02-security-groups.png
│   ├── 03-kafka-running.png
│   ├── 04-mongodb.png
│   ├── 05-producer.png
│   ├── 06-processor.png
│   ├── 07-rest-api.png
│   └── 08-end-to-end-test.png
|
├── config/
│   └── ...
|
├── scripts/
│   └── ...
|
├── producer/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── <producer source>
|
└── processor/
    ├── Dockerfile
    ├── requirements.txt
    └── <processor/API source>
```

The final repository structure will be updated to match the actual implementation.

---

# 18. Reproduction Procedure

A new deployment should be reproducible by following these high-level steps:

1. Create the documented AWS network.
2. Create the required Security Groups.
3. Launch the documented Ubuntu EC2 instances.
4. Configure SSH key-only authentication.
5. Install required host software.
6. Install and configure Kafka.
7. Create the Kafka topic.
8. Install and configure MongoDB.
9. Build and launch the Producer container.
10. Build and launch the Processor/API container.
11. Configure service startup behavior.
12. Run standalone component tests.
13. Run the complete end-to-end test.
14. Verify the REST endpoint.
15. Verify security controls.
16. Perform reboot/persistence testing.

Detailed commands are documented in:

```text
docs/commands.md
```

---

# 19. Deviations / Issues Encountered

Any difference between the original reference architecture and the final deployment is documented here.

| Issue / Deviation | Reason     | Solution / Decision | Validation     |
| ----------------- | ---------- | ------------------- | -------------- |
| `<issue>`         | `<reason>` | `<solution>`        | `<validation>` |

Potential examples include:

* EC2 instance sizing changed because of AWS Free Tier constraints
* Kafka configuration changed because of version compatibility
* service ports/configuration changed from the initial design
* a software version was changed after compatibility testing

If there are no significant deviations:

```text
No significant deviations from the selected reference stack.
```

---

# 20. Cost / AWS Free Tier Considerations

The deployment is designed to minimize unnecessary AWS charges while still satisfying the assignment requirements.

Before launching resources, the Free Tier benefits/credits applicable to the AWS account will be checked.

The following will be recorded:

| Item                                    | Actual Configuration |
| --------------------------------------- | -------------------- |
| AWS Free Tier model/account eligibility | `<verified>`         |
| EC2 instance types                      | `<actual>`           |
| Number of EC2 instances                 | `<actual>`           |
| EBS storage                             | `<actual>`           |
| Public IPv4 usage                       | `<actual>`           |
| Estimated/observed cost                 | `<actual>`           |

Resources that are not needed after testing should be stopped or terminated as appropriate.

Any deviation from the assignment's recommended approximately 2 vCPU / 4 GB RAM VM size due to Free Tier constraints will be explicitly documented rather than hidden.

---

# 21. Integrity Packet

The CA0 Integrity Packet is available at:

[`docs/integrity-packet.md`](docs/integrity-packet.md)

It documents:

* claims made about the deployment
* supporting evidence
* assumptions
* design decisions
* AI-generated guidance used
* guidance accepted
* guidance rejected
* external documentation used for validation
* validation procedures
* final verification results

## Evidence Philosophy

Important deployment claims should be supported by observable evidence.

Example:

```text
Claim:
Producer messages successfully reach MongoDB through Kafka and the processor.

Evidence:
Producer log + processor log + MongoDB query containing the same message_id.

Validation:
A new message was generated and traced through all pipeline stages.
```

---

# 22. Demo Video

A 1–2 minute demonstration will show:

1. required services running
2. producer generating/publishing data
3. Kafka participating in the message flow
4. processor consuming/processing the message
5. MongoDB containing the resulting record
6. REST API request and successful response

**Demo Video:** `<external-video-link>`

---

# 23. Final Verification Checklist

## Infrastructure

* [ ] 3–4 AWS EC2 VMs provisioned
* [ ] Instance sizing documented
* [ ] Any difference from approximately 2 vCPU / 4 GB documented
* [ ] VM names documented
* [ ] Private IPs documented
* [ ] Public IPs documented where applicable
* [ ] Region documented
* [ ] Availability Zone documented
* [ ] VPC documented
* [ ] Subnet/CIDR documented
* [ ] Instance types documented
* [ ] AMI/OS documented

## Pipeline

* [ ] Producer operational
* [ ] Kafka operational
* [ ] Kafka topic created
* [ ] Processor operational
* [ ] MongoDB operational
* [ ] Producer → Kafka verified
* [ ] Kafka → Processor verified
* [ ] Processor → MongoDB verified
* [ ] Complete end-to-end flow verified
* [ ] Correlated message/record captured as evidence

## REST API

* [ ] REST endpoint documented
* [ ] Method documented
* [ ] Port documented
* [ ] Successful request demonstrated
* [ ] Successful response captured

## Security

* [ ] SSH key authentication works
* [ ] Password SSH disabled
* [ ] SSH access appropriately restricted
* [ ] Kafka access restricted
* [ ] MongoDB access restricted
* [ ] Minimal inbound ports
* [ ] Containers non-root where supported
* [ ] No AWS credentials committed
* [ ] No SSH private keys committed
* [ ] No secrets exposed in screenshots

## Service Management

* [ ] Required services start on boot
* [ ] Reboot test performed
* [ ] Log locations/commands documented

## Documentation

* [ ] README complete
* [ ] Reference stack documented
* [ ] Architecture decisions documented
* [ ] Trade-offs documented
* [ ] Configuration summary complete
* [ ] Network diagram complete
* [ ] Trust boundaries shown
* [ ] Screenshots included
* [ ] Software versions documented
* [ ] Commands/instructions documented
* [ ] Deviations documented
* [ ] Reproduction procedure documented

## Submission

* [ ] Integrity Packet complete
* [ ] End-to-end evidence captured
* [ ] Demo video recorded
* [ ] Demo video link added
* [ ] Repository reviewed for secrets
* [ ] Repository pushed to GitHub

---

# 24. AI Assistance

AI assistance was used for technical guidance, architecture discussion, troubleshooting, and documentation support.

AI-generated recommendations are not treated as evidence that the deployment works.

Recommendations used during CA0 are validated using one or more of the following:

* official documentation
* actual AWS configuration
* command output
* service status
* application logs
* network tests
* database queries
* REST API responses
* end-to-end testing

AI recommendations that are rejected or modified are also recorded when relevant.

Detailed AI usage, assumptions, validation, accepted guidance, and rejected guidance are documented in the **Integrity Packet**.
