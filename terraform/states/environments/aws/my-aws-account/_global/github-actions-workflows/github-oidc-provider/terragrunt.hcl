include {
  path = find_in_parent_folders()
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  account_id  = local.account_vars.locals.account_id
  region      = local.region_vars.locals.region
  environment = local.environment_vars.locals.environment
}

terraform {
  source = "${get_repo_root()}/terraform/modules/github-oidc"
}

inputs = {
  github_repos = [
    "geek-kb/aidoc_assignment"
  ]
  thumbprint_list = [
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]
  tags = {
    Environment = local.environment
    Project     = "GitHubActions"
  }
}
