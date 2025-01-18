# terragrunt_version_constraint = "= 0.36.1"
terraform_version_constraint  = "= 1.5.5"

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  account_name     = local.account_vars.locals.account_name
  account_id       = local.account_vars.locals.account_id
  region           = local.region_vars.locals.region

  assignment_prefix = "aidoc-devops2-ex"

  common_vars = merge(
    local.account_vars.locals,
    local.region_vars.locals
  )

  common_tags = {
    "Account"     = local.account_vars.locals.account_name
    "Provisioner" = "Terraform"
    "Region"      = local.region_vars.locals.region
  }
}

# remote_state {
#   backend = "s3"
#   generate = {
#     path      = "backend.tf"
#     if_exists = "overwrite_terragrunt"
#   }
#   config = {
#     bucket         = "${local.assignment_prefix}-terraform-state"
#     key            = "${path_relative_to_include()}/terraform.tfstate"
#     region         = "${local.region}"
#     encrypt        = true
#     kms_key_id     = "arn:aws:kms:${local.region}:${local.account_id}:alias/dev/terraform-state-key"
#     dynamodb_table = "terraform-state-locks"
#   }
# }

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.84.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = ">= 0.7.2"
    }
  }
}
provider "aws" {
  region = "${local.region}"
}

provider "sops" {}
EOF
}

inputs = merge(
  local.common_vars,
  {
    tags = local.common_tags
  }
)
