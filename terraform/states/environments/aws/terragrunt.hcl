# terragrunt_version_constraint = "= 0.36.1"
terraform_version_constraint = "= 1.5.5"

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  account_name = local.account_vars.locals.account_name
  account_id   = local.account_vars.locals.account_id
  region       = local.region_vars.locals.region

  assignment_prefix = "aidoc-devops2-ex"

  common_vars = merge(
    local.account_vars.locals,
    local.region_vars.locals,
    {
      tags = {
        "Account"     = local.account_vars.locals.account_name
        "Provisioner" = "Terraform"
        "Region"      = local.region_vars.locals.region
      }
    }
  )
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    bucket         = "aidoc-devops2-ex-terraform-state-l9bsj3h"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:eu-west-1:${local.account_id}:key/0544f8e2-f4a6-4b64-8466-fdf76d6e96be"
    dynamodb_table = "aidoc-devops2-ex-terraform-state-locks"

    # Prevent accidental state corruption
    skip_metadata_api_check = true
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.84.0, < 6.0.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = ">= 0.7.2"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

provider "sops" {}
EOF
}

inputs = local.common_vars
