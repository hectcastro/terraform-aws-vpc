provider "aws" {
	access_key = "${var.aws_access_key}"
	secret_key = "${var.aws_secret_key}"
	region = "us-east-1"
}

resource "aws_vpc" "default" {
	cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "default" {
	vpc_id = "${aws_vpc.default.id}"
}

# NAT instance

resource "aws_security_group" "nat" {
	name = "nat"
	description = "Allow services from the private subnet through NAT"

	ingress {
		from_port = 0
		to_port = 65535
		protocol = "tcp"
		cidr_blocks = ["${aws_subnet.us-east-1b-private.cidr_block}"]
	}
	ingress {
		from_port = 0
		to_port = 65535
		protocol = "tcp"
		cidr_blocks = ["${aws_subnet.us-east-1d-private.cidr_block}"]
	}

	vpc_id = "${aws_vpc.default.id}"
}

resource "aws_instance" "nat" {
	ami = "${var.aws_nat_ami}"
	availability_zone = "us-east-1b"
	instance_type = "m1.small"
	key_name = "${var.aws_key_name}"
	security_groups = ["${aws_security_group.nat.id}"]
	subnet_id = "${aws_subnet.us-east-1b-public.id}"
	associate_public_ip_address = true
	source_dest_check = false
}

resource "aws_eip" "nat" {
	instance = "${aws_instance.nat.id}"
	vpc = true
}

# Public subnets

resource "aws_subnet" "us-east-1b-public" {
	vpc_id = "${aws_vpc.default.id}"

	cidr_block = "10.0.0.0/24"
	availability_zone = "us-east-1b"
}

resource "aws_subnet" "us-east-1d-public" {
	vpc_id = "${aws_vpc.default.id}"

	cidr_block = "10.0.2.0/24"
	availability_zone = "us-east-1d"
}

# Routing table for public subnets

resource "aws_route_table" "us-east-1-public" {
	vpc_id = "${aws_vpc.default.id}"

	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = "${aws_internet_gateway.default.id}"
	}
}

resource "aws_route_table_association" "us-east-1b-public" {
	subnet_id = "${aws_subnet.us-east-1b-public.id}"
	route_table_id = "${aws_route_table.us-east-1-public.id}"
}

resource "aws_route_table_association" "us-east-1d-public" {
	subnet_id = "${aws_subnet.us-east-1d-public.id}"
	route_table_id = "${aws_route_table.us-east-1-public.id}"
}

# Private subsets

resource "aws_subnet" "us-east-1b-private" {
	vpc_id = "${aws_vpc.default.id}"

	cidr_block = "10.0.1.0/24"
	availability_zone = "us-east-1b"
}

resource "aws_subnet" "us-east-1d-private" {
	vpc_id = "${aws_vpc.default.id}"

	cidr_block = "10.0.3.0/24"
	availability_zone = "us-east-1d"
}

# Routing table for private subnets

resource "aws_route_table" "us-east-1-private" {
	vpc_id = "${aws_vpc.default.id}"

	route {
		cidr_block = "0.0.0.0/0"
		instance_id = "${aws_instance.nat.id}"
	}
}

resource "aws_route_table_association" "us-east-1b-private" {
	subnet_id = "${aws_subnet.us-east-1b-private.id}"
	route_table_id = "${aws_route_table.us-east-1-private.id}"
}

resource "aws_route_table_association" "us-east-1d-private" {
	subnet_id = "${aws_subnet.us-east-1d-private.id}"
	route_table_id = "${aws_route_table.us-east-1-private.id}"
}

# Bastion

resource "aws_security_group" "bastion" {
	name = "bastion"
	description = "Allow SSH traffic from the internet"

	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	vpc_id = "${aws_vpc.default.id}"
}

resource "aws_instance" "bastion" {
	ami = "${var.aws_ubuntu_ami}"
	availability_zone = "us-east-1b"
	instance_type = "t2.micro"
	key_name = "${var.aws_key_name}"
	security_groups = ["${aws_security_group.bastion.id}"]
	subnet_id = "${aws_subnet.us-east-1b-public.id}"
}

resource "aws_eip" "bastion" {
	instance = "${aws_instance.bastion.id}"
	vpc = true
}
