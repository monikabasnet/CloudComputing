data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = [var.ami_architecture]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}


resource "aws_key_pair" "ca1" {
  key_name   = "${var.project_name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))

  tags = {
    Name = "${var.project_name}-key"
  }
}


resource "aws_instance" "producer" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.producer.id]
  key_name                    = aws_key_pair.ca1.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name      = "${var.project_name}-producer"
    Component = "Producer"
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}


resource "aws_instance" "kafka" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.kafka.id]
  key_name                    = aws_key_pair.ca1.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name      = "${var.project_name}-kafka"
    Component = "Kafka"
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}


resource "aws_instance" "processor" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.processor.id]
  key_name                    = aws_key_pair.ca1.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name      = "${var.project_name}-processor"
    Component = "Processor"
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}


resource "aws_instance" "mongodb" {
  ami                         = var.mongodb_ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.mongodb.id]
  key_name                    = aws_key_pair.ca1.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name      = "${var.project_name}-mongodb"
    Component = "MongoDB"
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}

