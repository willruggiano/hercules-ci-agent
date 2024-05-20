{inputs, ...}: {
  perSystem = {
    config,
    lib,
    pkgs,
    ...
  }: {
    packages = let
      t-nix = inputs.terraform-nixos;
    in {
      main-tf = pkgs.writeText "main.tf" ''
        terraform {
            backend "remote" {
                organization = "willruggiano"

                workspaces {
                    name = "hercules-ci"
                }
            }
        }

        provider "aws" {
            region = "us-east-2"
            profile = "personal"
        }

        module "nixos_image" {
            source  = "git::https://github.com/nix-community/terraform-nixos.git//aws_image_nixos?ref=${t-nix.rev}"
            release = "latest"
        }

        resource "aws_security_group" "ssh_and_egress" {
            ingress {
                from_port   = 22
                to_port     = 22
                protocol    = "tcp"
                cidr_blocks = [ "0.0.0.0/0" ]
            }

            egress {
                from_port       = 0
                to_port         = 0
                protocol        = "-1"
                cidr_blocks     = ["0.0.0.0/0"]
            }
        }

        resource "tls_private_key" "state_ssh_key" {
            algorithm = "ED25519"
        }

        resource "local_sensitive_file" "machine_ssh_key" {
            content = tls_private_key.state_ssh_key.private_key_openssh
            filename          = "''${path.module}/id_ed25519"
            file_permission   = "0600"
        }

        resource "aws_key_pair" "generated_key" {
            key_name   = "generated-key-''${sha256(tls_private_key.state_ssh_key.public_key_openssh)}"
            public_key = tls_private_key.state_ssh_key.public_key_openssh
        }

        resource "aws_instance" "machine" {
            ami             = module.nixos_image.ami
            instance_type   = "t3.micro"
            security_groups = [ aws_security_group.ssh_and_egress.name ]
            key_name        = aws_key_pair.generated_key.key_name

            root_block_device {
                volume_size = 50 # GiB
            }
        }

        output "public_dns" {
            value = aws_instance.machine.public_dns
        }
      '';
    };
  };
}
