output "vpc_id" {
  description = "ID of the Terraform-managed CA1 VPC."
  value       = aws_vpc.ca1.id
}

output "public_subnet_id" {
  description = "ID of the CA1 public subnet."
  value       = aws_subnet.public.id
}

output "ubuntu_ami_id" {
  description = "Ubuntu 24.04 LTS AMI selected for the CA1 EC2 instances."
  value       = data.aws_ami.ubuntu.id
}

output "producer_public_ip" {
  description = "Public IPv4 address of the Producer VM."
  value       = aws_instance.producer.public_ip
}

output "producer_private_ip" {
  description = "Private IPv4 address of the Producer VM."
  value       = aws_instance.producer.private_ip
}

output "kafka_public_ip" {
  description = "Public IPv4 address of the Kafka VM."
  value       = aws_instance.kafka.public_ip
}

output "kafka_private_ip" {
  description = "Private IPv4 address of the Kafka VM."
  value       = aws_instance.kafka.private_ip
}

output "processor_public_ip" {
  description = "Public IPv4 address of the Processor VM."
  value       = aws_instance.processor.public_ip
}

output "processor_private_ip" {
  description = "Private IPv4 address of the Processor VM."
  value       = aws_instance.processor.private_ip
}

output "mongodb_public_ip" {
  description = "Public IPv4 address of the MongoDB VM."
  value       = aws_instance.mongodb.public_ip
}

output "mongodb_private_ip" {
  description = "Private IPv4 address of the MongoDB VM."
  value       = aws_instance.mongodb.private_ip
}

output "kafka_topic" {
  description = "Kafka topic used by the CA1 pipeline."
  value       = var.kafka_topic
}

output "kafka_bootstrap_server" {
  description = "Internal Kafka bootstrap address used by the Producer and Processor."
  value       = "${aws_instance.kafka.private_ip}:${var.kafka_port}"
}

output "mongodb_connection_target" {
  description = "Internal MongoDB host and port used by the Processor."
  value       = "${aws_instance.mongodb.private_ip}:${var.mongodb_port}"
}

output "rest_api_base_url" {
  description = "Public REST API base URL exposed by the Processor."
  value       = "http://${aws_instance.processor.public_ip}:${var.rest_api_port}"
}



output "mongodb_database" {
  description = "MongoDB database used by the pipeline."
  value       = var.mongodb_database
}

output "mongodb_collection" {
  description = "MongoDB collection used by the pipeline."
  value       = var.mongodb_collection
}


output "mongodb_ami_id" {
  description = "Pinned Ubuntu 24.04 LTS AMI used by the MongoDB VM."
  value       = var.mongodb_ami_id
}