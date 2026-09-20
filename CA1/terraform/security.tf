resource "aws_security_group" "producer" {
  name        = "${var.project_name}-producer-sg"
  description = "Security group for the CA1 Producer"
  vpc_id      = aws_vpc.ca1.id

  tags = {
    Name      = "${var.project_name}-producer-sg"
    Component = "Producer"
  }
}

resource "aws_security_group" "kafka" {
  name        = "${var.project_name}-kafka-sg"
  description = "Security group for the CA1 Kafka broker"
  vpc_id      = aws_vpc.ca1.id

  tags = {
    Name      = "${var.project_name}-kafka-sg"
    Component = "Kafka"
  }
}

resource "aws_security_group" "processor" {
  name        = "${var.project_name}-processor-sg"
  description = "Security group for the CA1 Processor and REST API"
  vpc_id      = aws_vpc.ca1.id

  tags = {
    Name      = "${var.project_name}-processor-sg"
    Component = "Processor"
  }
}

resource "aws_security_group" "mongodb" {
  name        = "${var.project_name}-mongodb-sg"
  description = "Security group for the CA1 MongoDB database"
  vpc_id      = aws_vpc.ca1.id

  tags = {
    Name      = "${var.project_name}-mongodb-sg"
    Component = "MongoDB"
  }
}



resource "aws_vpc_security_group_egress_rule" "producer_all_outbound" {
  security_group_id = aws_security_group.producer.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  description = "Allow Producer outbound traffic"
}

resource "aws_vpc_security_group_egress_rule" "kafka_all_outbound" {
  security_group_id = aws_security_group.kafka.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  description = "Allow Kafka outbound traffic"
}

resource "aws_vpc_security_group_egress_rule" "processor_all_outbound" {
  security_group_id = aws_security_group.processor.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  description = "Allow Processor outbound traffic"
}

resource "aws_vpc_security_group_egress_rule" "mongodb_all_outbound" {
  security_group_id = aws_security_group.mongodb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  description = "Allow MongoDB outbound traffic"
}


resource "aws_vpc_security_group_ingress_rule" "producer_ssh" {
  security_group_id = aws_security_group.producer.id

  cidr_ipv4   = var.admin_cidr
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"

  description = "SSH from trusted administrator address"
}

resource "aws_vpc_security_group_ingress_rule" "kafka_ssh" {
  security_group_id = aws_security_group.kafka.id

  cidr_ipv4   = var.admin_cidr
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"

  description = "SSH from trusted administrator address"
}

resource "aws_vpc_security_group_ingress_rule" "processor_ssh" {
  security_group_id = aws_security_group.processor.id

  cidr_ipv4   = var.admin_cidr
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"

  description = "SSH from trusted administrator address"
}

resource "aws_vpc_security_group_ingress_rule" "mongodb_ssh" {
  security_group_id = aws_security_group.mongodb.id

  cidr_ipv4   = var.admin_cidr
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"

  description = "SSH from trusted administrator address"
}

resource "aws_vpc_security_group_ingress_rule" "kafka_from_producer" {
  security_group_id            = aws_security_group.kafka.id
  referenced_security_group_id = aws_security_group.producer.id

  from_port   = var.kafka_port
  to_port     = var.kafka_port
  ip_protocol = "tcp"

  description = "Kafka traffic from Producer"
}

resource "aws_vpc_security_group_ingress_rule" "kafka_from_processor" {
  security_group_id            = aws_security_group.kafka.id
  referenced_security_group_id = aws_security_group.processor.id

  from_port   = var.kafka_port
  to_port     = var.kafka_port
  ip_protocol = "tcp"

  description = "Kafka traffic from Processor"
}

resource "aws_vpc_security_group_ingress_rule" "mongodb_from_processor" {
  security_group_id            = aws_security_group.mongodb.id
  referenced_security_group_id = aws_security_group.processor.id

  from_port   = var.mongodb_port
  to_port     = var.mongodb_port
  ip_protocol = "tcp"

  description = "MongoDB traffic from Processor"
}

resource "aws_vpc_security_group_ingress_rule" "processor_rest" {
  security_group_id = aws_security_group.processor.id

  cidr_ipv4   = var.admin_cidr
  from_port   = var.rest_api_port
  to_port     = var.rest_api_port
  ip_protocol = "tcp"

  description = "REST API access from trusted administrator address"
}