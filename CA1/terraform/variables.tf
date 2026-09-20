variable "aws_region" {
  description = "AWS region where the CA1 infrastructure is deployed."
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Name used to identify CA1 AWS resources."
  type        = string
  default     = "ca1"
}

variable "instance_type" {
  description = "EC2 instance type used by the four CA1 virtual machines."
  type        = string
  default     = "c7i-flex.large"
}

variable "vpc_cidr" {
  description = "CIDR block for the CA1 VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the CA1 public subnet."
  type        = string
  default     = "10.10.1.0/24"
}

variable "kafka_port" {
  description = "Port used by the Kafka broker."
  type        = number
  default     = 9092
}

variable "mongodb_port" {
  description = "Port used by MongoDB."
  type        = number
  default     = 27017
}

variable "rest_api_port" {
  description = "Port exposed by the Processor REST API."
  type        = number
  default     = 8080
}

variable "kafka_topic" {
  description = "Kafka topic used by the authentication-event pipeline."
  type        = string
  default     = "auth-events"
}

variable "producer_image" {
  description = "Docker image name and tag for the authentication-event Producer."
  type        = string
  default     = "ca1-auth-producer:1.0"
}

variable "processor_image" {
  description = "Docker image name and tag for the threat Processor."
  type        = string
  default     = "ca1-threat-processor:1.2"
}

variable "mongodb_version" {
  description = "MongoDB version used by the CA1 database."
  type        = string
  default     = "8.0.29"
}

variable "kafka_version" {
  description = "Apache Kafka version used by the CA1 broker."
  type        = string
  default     = "4.3.1"
}

variable "admin_cidr" {
  description = "Trusted public IPv4 CIDR allowed to SSH to CA1 EC2 instances."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && endswith(var.admin_cidr, "/32")
    error_message = "admin_cidr must be a valid single-host IPv4 CIDR ending in /32."
  }
}


variable "ami_architecture" {
  description = "CPU architecture required for the Ubuntu EC2 AMI."
  type        = string
  default     = "x86_64"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key used for EC2 access."
  type        = string
  default     = "~/.ssh/ca1-key.pub"
}


variable "mongodb_database" {
  description = "MongoDB database used by the threat-processing pipeline."
  type        = string
  default     = "threat_monitor"
}

variable "mongodb_collection" {
  description = "MongoDB collection used to store processed security events."
  type        = string
  default     = "security_events"
}


variable "mongodb_ami_id" {
  description = "Pinned Ubuntu 24.04 LTS AMI for MongoDB, recovered from the working CA0 database VM."
  type        = string
  default     = "ami-0ea1cddefe0c4aed5"
}