locals {
 name_prefix = "luke27"
}

locals {
 selected_subnet_ids = var.public_subnet ? data.aws_subnets.public.ids : data.aws_subnets.private.ids
}

resource "aws_security_group" "a27" {
 name_prefix = "${local.name_prefix}-ec2"
 description = "Allow traffic to this a27-ec2"
 vpc_id      = data.aws_vpc.selected.id


# Allow HTTP traffic from anywhere
  ingress {
   from_port        = 443
   to_port          = 443
   protocol         = "tcp"
   cidr_blocks      = ["0.0.0.0/0"]
   ipv6_cidr_blocks = ["::/0"]
 }

 # Allow SSH access only from anywhere
 ingress {
   from_port        = 22
   to_port          = 22
   protocol         = "tcp"
   cidr_blocks      = ["0.0.0.0/0"]
   ipv6_cidr_blocks = ["::/0"]
 }


 egress {
   from_port        = 0
   to_port          = 0
   protocol         = "-1"
   cidr_blocks      = ["0.0.0.0/0"]
   ipv6_cidr_blocks = ["::/0"]
 }


 lifecycle {
   create_before_destroy = true
 }
}


# Create an EC2 instance
resource "aws_instance" "a27ec2" {
  ami           = data.aws_ami.latest.id
  instance_type = var.instance_type
  subnet_id     = local.selected_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.a27.id]
  key_name      = var.key_name

# Script that formats the ebs to ext4
  user_data = <<-EOF
    #!/bin/bash
    # Wait for the volume to be attached
    sleep 10
    # Create a file system (EXT4) on the new volume
    sudo mkfs -t ext4 /dev/xvdf
    # Create a mount point
    sudo mkdir -p /mnt/data
    # Mount the volume
    sudo mount /dev/xvdf /mnt/data
    # Persist the mount in /etc/fstab
    echo "/dev/xvdf /mnt/data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
  EOF

 associate_public_ip_address = true
  tags = {
    Name = "${local.name_prefix}-ec2"
  }
}

# Create a 1GB EBS volume in the same AZ as the EC2 instance
resource "aws_ebs_volume" "a27ebs" {
  availability_zone = aws_instance.a27ec2.availability_zone
  size              = 1  # Size in GB

  tags = {
    Name = "${local.name_prefix}-ebs"
  }
}

# Attach the EBS volume to the EC2 instance
resource "aws_volume_attachment" "ebs_attach" {
  device_name = "/dev/xvdf" 
  volume_id   = aws_ebs_volume.a27ebs.id
  instance_id = aws_instance.a27ec2.id
}