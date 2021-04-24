
provider "aws" {
  region = "us-east-2"
}


resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "tf-example"
  }
}

resource "aws_subnet" "my_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "tf-example-subnet"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
     Name = "web-gw"
   }
}

resource "aws_security_group" "my_sec_group" {
  name        = "my_sec_group"
  description = "My Sec group"
  vpc_id      = aws_vpc.my_vpc.id

  # ingress {
  #   description      = "TLS from VPC"
  #   from_port        = 443
  #   to_port          = 443
  #   protocol         = "tcp"
  #   cidr_blocks      = ["0.0.0.0/0"]
  # }

  # ingress {
  #   description      = "HTTP from VPC"
  #   from_port        = 80
  #   to_port          = 80
  #   protocol         = "tcp"
  #   cidr_blocks      = ["0.0.0.0/0"]
  # }

  ingress {
    description      = "mysql"
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

resource "tls_private_key" "tls_pk" {
  algorithm = "RSA"
}

module "key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name   = "terraform-key"
  public_key = tls_private_key.tls_pk.public_key_openssh
}


resource "aws_instance" "my_instance" {
  ami             = "ami-01e7ca2ef94a0ae86"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.my_subnet.id
  security_groups = [aws_security_group.my_sec_group.id]
  key_name        = "terraform-key"
  tags = {
     Name = "web-vm"
   }
}

resource "aws_eip" "my_eip" {
  vpc      = true
  instance = aws_instance.my_instance.id

}

resource "aws_route_table" "route-table-test-env" {
  vpc_id = aws_vpc.my_vpc.id
   route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
   }
   tags = {
     Name = "test-env-route-table"
   }
}
resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.route-table-test-env.id
}


resource "null_resource" "copy-mysql-folder" {
 
  connection {
    host        = "${aws_eip.my_eip.public_ip}"
    type        = "ssh"
    agent       = false
    private_key = "${tls_private_key.tls_pk.private_key_pem}"
    user        = "ubuntu"
  }  

  provisioner "file" {
    source      = "mysql"
    destination = "/home/ubuntu"
  }

}

resource "null_resource" "install-mysql-server" {
  connection {
    host        = "${aws_eip.my_eip.public_ip}"
    type        = "ssh"
    agent       = false
    private_key = "${tls_private_key.tls_pk.private_key_pem}"
    user        = "ubuntu"
  }  

  provisioner "remote-exec" {
    inline = [
      "sleep 20",
      "sudo apt update",
      "sudo apt install -y mysql-server-5.7",
      "sudo mysql < /home/ubuntu/mysql/update_root.sql",
      "sudo bash -c 'cat /home/ubuntu/mysql/mysqld.cnf > /etc/mysql/mysql.conf.d/mysqld.cnf'",
      "sudo service mysql restart",
    ]
  }
  depends_on = [aws_instance.my_instance, aws_eip.my_eip]
}

output "IP" {
    value = "${aws_eip.my_eip.public_ip}"
}
