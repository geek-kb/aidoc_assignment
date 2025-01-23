# Aidoc Home Assignment - Deployment and Design Documentation

This document provides an **overview of the chosen technologies, directory structure, and deployment process** for the Aidoc home assignment. It explains **why the architecture was designed this way** and serves as a **step-by-step deployment guide**.

Since there are many directories in the structure I will break it to pieces, starting from the repository root.

```
.
├── python
│   ├── order_retrieval
│   │   ├── code
│   │   │   └── __pycache__
│   │   └── code_test
│   │       └── tests
│   │           └── __pycache__
│   └── order_verification
│       ├── code
│       └── code_test
│           ├── order_verification
│           │   └── __pycache__
│           └── tests
│               └── __pycache__
```

The Python functions I've been instructed to write can be found in the python directory along with their tests.
In order to run the tests, simply browse into `<function_name>/code_test` and run:

```bash
python -m pytest tests/ -v
```

```bash
└── terraform
    ├── modules
    │   ├── dynamodb
    │   ├── ecr
    │   ├── github-oidc
    │   ├── iam-role
    │   ├── kms
    │   ├── lambda
    │   ├── s3
    │   ├── sqs
    │   ├── ssm
    └── states
```

Under the **terraform/** directory, two primary subdirectories exist:

1. **modules/** - Contains all reusable Terraform modules, each dedicated to a specific AWS resource.
2. **states/** - Represents the actual infrastructure environments, organized by AWS account, region, and deployment stage.

## Infrastructure Design Rationale

Initially, my goal was to strictly follow the assignment instructions. However, I soon realized this was an opportunity to design a scalable and maintainable infrastructure **from scratch**—something I hadn't done before. This led me to carefully consider long-term **growth, security, and flexibility** while structuring the infrastructure.

The result is a **multi-account, multi-region** architecture that is **modular, secure, and scalable**.

```
└── states
    └── environments
        └── aws
            └── my-aws-account
                ├── _global
                │   ├── _bootstrap
                │   │   ├── dynamodb
                │   │   │   └── terraform-state-locks
                │   │   ├── github-oidc
                │   │   │   └── github-oidc-provider
                │   │   ├── iam-role
                │   │   │   └── sops
                │   │   ├── kms
                │   │   │   ├── sops-key
                │   │   │   └── terraform-state-key
                │   │   └── s3
                │   │       └── terraform-state
                │   ├── admin
                │   │   └── iam-role
                │   │       └── admin
                │   ├── github-actions-workflows
                │   │   └── iam-role
                │   │       ├── github-actions-workflows
                │   │       └── github-oidc-auth
                │   └── terraform
                │       └── iam-role
                │           ├── state-manager
                │           └── terraform
                ├── eu-north-1
                │   └── dev-stockholm-1
                │       ├── dynamodb
                │       │   └── orders
                │       ├── ecr
                │       │   └── order-retrieval
                │       ├── iam-role
                │       │   ├── retrieval_lambda_execution
                │       │   └── verification_lambda_execution
                │       ├── kms
                │       │   └── data-encryption
                │       ├── lambda
                │       │   ├── order-retrieval
                │       │   │   ├── lambda_source_code
                │       │   │   │   └── __pycache__
                │       │   │   └── tests
                │       │   │       └── __pycache__
                │       │   └── order-verification
                │       │       ├── lambda_source_code
                │       │       └── test_payloads
                │       ├── s3
                │       │   ├── order-verification-code
                │       │   └── ordering-system
                │       ├── sqs
                │       │   └── order-processor
                │       └── ssm
                │           └── managed
```

If it would be a real case scenario, I'd separate the `modules` and the `states` to two different repositories, but for the sake of the assignment these are directories.

`environments` is the top level of the `states` directory and below it you will find the `aws` directory.

I thought that today, for the assignment, I only manage one provider of resources - AWS, but in the real world I would probably manage resources by many more providers.

Under `aws` directory, you can find a representation of a single AWS account, but again, in a real world scenario, a company would probably have an organizational account which
contains more `accounts` (production, dev, qa, etc..), so this is where I would place the other AWS accounts.

In addition to that, you can find there the `parent terragrunt.hcl` file, the highest one in the hierarchy which contains the `remote state s3 backend` and `provider` settings along with other common tags.

If I had more accounts, that's where I would define their account level variables.

Under each `account` directory, I created a directory per `AWS region`, for the assignment I created only 2 regional directories, but only one of them is actually configured (`dev-stockholm-1`).

In each regional directory like that, you can find a `region.hcl` file where I placed variables that are region wide, the other directory in the level of the regions is also treated like a region, but in fact it's the path where I placed all the `_global` resources, resources that every region requires and since it's only "the beginning" of the so-called company's infrastructure I created, you could treat the `_global` directory like a management region.

Under each `region` directory, you can find `environment` directories like `dev-stockholm-1`, this structure allows you having a number of different environments under the same region if needed.

Under each environment directory, you can find the state directories of the modules that are active and configured in that environment and under these, the actual names of the managed resources and
their `terragrunt.hcl`.

### **Why This Structure?**

#### **Scalability**

- Supports **multi-region** and **multi-environment** deployments.
- Modular Terraform states allow for easy expansion.

#### **Security**

- **IAM roles** are strictly managed and restricted.
- Uses **AWS KMS encryption** for sensitive data.
- **GitHub OIDC authentication** eliminates the need for long-lived AWS credentials.

#### **Flexibility & Maintainability**

- Separate **modules/** and **states/** allow reuse and simplified management.
- Clear **environment isolation** (e.g., `dev-stockholm-1`, `dev-ireland-1`).
- **Global resources** (e.g., `_bootstrap`) ensure efficient resource sharing across environments.

# Environment Deployment Guide

This document covers the steps (in the correct order) to deploy an environment.

It can be automated to some point because I made sure to lower the level of the dependecies by separating the foundtional infrastructure resources from the rest of the resources, so once the foundational (bootstrap) resources are configured, the rest of the configuration is pretty straight-forward.

This is the flow of deployment as I see it:

```mermaid
graph TD
    A[Admin User] -->|Creates| B[Bootstrap Resources]
    B -->|Contains| C[OIDC Auth Role]
    B -->|Contains| D[KMS Keys]
    B -->|Contains| E[State Bucket]
    B -->|Contains| F[DynamoDB Locks]
    C -->|Authenticates| G[GitHub Actions]
    G -->|Assumes| H[GitHub Workflows Role]
    H -->|Assumes| I[Terraform Role]
    H -->|Assumes| J[State Manager Role]
    H -->|Assumes| K[SOPS Role]
    I -->|Deploys| L[Application Resources]
    J -->|Manages| E
    K -->|Uses| D
```

### Bootstrap Resources Plan

It's important to deploy these resources in the following order:

1. S3 Bucket for Terraform state
2. DynamoDB table for state locking
3. IAM Admin Role
4. KMS key for encryption (optional)

Here's the list as Mermaid diagram code:

```mermaid
graph TD
    A[Bootstrap Resources] -->|Contains| B[S3 State Bucket]
    A -->|Contains| C[DynamoDB Lock Table]
    A -->|Contains| D[IAM Admin Role]
    A -->|Optional| E[KMS Key]

    B -->|Stores| F[Terraform State Files]
    C -->|Prevents| G[Concurrent Access]
    D -->|Manages| H[Infrastructure]
    E -->|Encrypts| B
```

These resources are considered "bootstrap" because they're the foundational infrastructure needed before Terraform can manage other resources effectively and securely.

The S3 bucket and DynamoDB table are particularly crucial as they enable:

- Remote state storage
- State locking
- Team collaboration
- State versioning

```mermaid
graph TD
    A[Admin User] -->|Creates| B[Bootstrap Resources]
    B -->|Creates| C[State Manager Role]
    C -->|Used by| D[Terraform Role]
    D -->|Deploys| E[Other Resources]
```

### Bootstrap Resource Creation Order

**Important**

Before you start deploying such an environment, comment out the `provider.tf` and `backend.tf` generation blocks in the parent `terragrunt.hcl` file (`aidoc_assignment/terraform/states/environments/aws`) in order to simplicate the process of creating the following resources (initial kms key, s3 bucket and dynamodb table)

Deployment procedure starts from here:

These steps should be run by browsing to each resource's folder and running `terragrunt apply`.

1. Create KMS keys first

   - Required for encrypting S3 bucket
   - Needed for DynamoDB encryption
   - Needed for Sops management

2. Create S3 bucket

   - Uses KMS key for encryption
   - Stores Terraform state

3. Create DynamoDB table
   - Uses same KMS key
   - Handles state locking

### Bootstrap Resources Build

1. **Verify Resources Created**

- [x] KMS key for encryption
- [x] S3 bucket for state storage
- [x] DynamoDB table for state locking

2. **Validation Steps**

```bash
cd /Users/itaig/src/aidoc_assignment/terraform/states/environments/aws/my-aws-account/_global/_bootstrap
terragrunt run-all plan
```

3. **Check Resources in AWS Console**

- KMS key with alias
- S3 bucket with versioning
- DynamoDB table with encryption

4. **Next Steps**

- Configure backend.tf to use these resources
  _. Test state locking
  _. Begin deploying application infrastructure

### Backend Configuration

1. **Steps**
   - Navigate to terragrunt repo root ("terraform/states/environments/aws") and edit terragrunt.hcl

- Uncomment generate block
- Configure S3 backend
- Add provider configuration
- Add necessary dependencies

1. **Verify**

```bash
cd terraform/states/environments/aws/my-aws-account/_global/_bootstrap
terragrunt run-all init
```

This is the parent `terragrunt.hcl` that should be placed under `terraform/states/environments/aws`:

```hcl
terraform_version_constraint = "= 1.5.5"

locals {
  account_name = "AWS_ALIAS or ACCOUNT_NAME"
  account_id   = "AWS_ACCOUNT_ID"
  region       = "AWS_REGION"

  assignment_prefix = "aidoc-devops2-ex"

  common_vars = {
    assignment_prefix = local.assignment_prefix
    account_id        = local.account_id
    account_name      = local.account_name
    region            = local.region
  }
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "${local.assignment_prefix}-terraform-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "${local.region}"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:${local.region}:${local.account_id}:alias/bootstrap/${local.assignment_prefix}-terraform-state-key"
    dynamodb_table = "${local.assignment_prefix}-terraform-state-locks"

    s3_bucket_tags = {
      Environment = "bootstrap"
      Project     = "ordering-system"
    }
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
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
  region = "${local.region}"
}
provider "sops" {}
EOF
}

inputs = local.common_vars

```

4. **Validation**

```bash
terragrunt validate
aws s3api get-bucket-versioning --bucket aidoc-devops2-ex-terraform-state
aws s3api get-bucket-encryption --bucket aidoc-devops2-ex-terraform-state
terragrunt init
```

Press 'y' to proceed with the bucket updates.

Expected output:

Success! The configuration is valid.

## Next Steps

6. Begin application infrastructure deployment
7. Configure SOPS encryption
8. Set up CI/CD pipeline

## Resource Dependencies

```mermaid
graph TD
    A[Admin Role] -->|Creates| B[KMS Keys]
    B -->|Encrypts| C[S3 Bucket]
    B -->|Encrypts| D[DynamoDB Table]
    C -->|Stores| E[Terraform State]
    D -->|Locks| E
```

### IAM Roles Deployment

1. Create State Manager Role

   - Manage S3 state bucket
   - Access DynamoDB locks
   - Use KMS key

2. Create Terraform Role

   - Full AWS access
   - Assume role from OIDC
   - KMS decrypt rights

3. Create GitHub Workflows Role
   - Limited AWS access
   - OIDC trust policy
   - Specific service permissions

### OIDC Authentication Flow

1. Role Structure:

```mermaid
graph TD
    A[GitHub Actions] -->|Assumes| B[OIDC Auth Role]
    B -->|Allows Assume| C[GitHub Workflows Role]
    C -->|Allows Assume| D[Terraform Role]
    C -->|Allows Assume| E[State Manager Role]
```

2. Creation Order:

- OIDC Auth Role (trust OIDC provider)
- GitHub Workflows Role (trust OIDC Auth)
- Terraform Role (trust GitHub Workflows)
- State Manager Role (trust GitHub Workflows)

3. Permissions:

- OIDC Auth: Only AssumeRole permissions
- GitHub Workflows: Limited AWS access + AssumeRole
- Terraform: Full AWS access
- State Manager: State management only

### SOPS Role

1. **Role Purpose**

   - Decrypt secrets using KMS
   - Used by GitHub Workflows
   - Limited to SOPS key access

2. **Permission Flow**

```mermaid
graph TD
    A[GitHub Actions] -->|Assumes| B[OIDC Auth]
    B -->|Assumes| C[GitHub Workflows]
    C -->|Assumes| D[SOPS Role]
    D -->|Uses| E[KMS SOPS Key]
```

3. **Implementation Steps**
   1. Add SOPS role to assumable roles in OIDC auth
   2. Create SOPS role with KMS permissions
   3. Update workflows role to assume SOPS role

### IAM Roles Usage Flow

1. **Authentication Flow**

```mermaid
graph TD
    A[GitHub Actions] -->|WebIdentity| B[OIDC Auth Role]
    B -->|AssumeRole| C[GitHub Workflows Role]
    C -->|AssumeRole| D[Other Roles]
    D --> E[SOPS Role]
    D --> F[Terraform Role]
    D --> G[State Manager Role]
```

2. **Use Cases**

```
| Role             | When to Use               | Example                                 |
| ---------------- | ------------------------- | --------------------------------------- |
| OIDC Auth        | Initial authentication    | `aws sts assume-role-with-web-identity` |
| GitHub Workflows | CI/CD operations          | Pushing artifacts, basic AWS operations |
| SOPS             | Secrets management        | Decrypt environment variables           |
| Terraform        | Infrastructure deployment | Create/update AWS resources             |
| State Manager    | State file operations     | Read/write terraform state              |
```

1. **Example Usage**

```yaml
# GitHub Actions Workflow Example
name: Deployment

jobs:
  deploy:
    permissions:
      id-token: write
      contents: read

    steps:
      # 1. Authenticate using OIDC
      - uses: aws-actions/configure-aws-credentials@v1
        with:
          role-to-assume: arn:aws:iam::${ACCOUNT_ID}:role/aidoc-devops2-ex-oidc-auth
          aws-region: eu-north-1

      # 2. Assume SOPS role to decrypt secrets
      - name: Assume SOPS Role
        run: |
          aws sts assume-role \
            --role-arn arn:aws:iam::${ACCOUNT_ID}:role/aidoc-devops2-ex-sops \
            --role-session-name sops-decrypt

      # 3. Assume Terraform role for deployment
      - name: Assume Terraform Role
        run: |
          aws sts assume-role \
            --role-arn arn:aws:iam::${ACCOUNT_ID}:role/aidoc-devops2-ex-terraform \
            --role-session-name terraform-deploy

      # 4. State Manager role used automatically by Terraform
      - name: Apply Terraform
        run: terragrunt apply
```

## Role Assume Examples - Role Flows

1. **OIDC Auth Role**

   ```mermaid
   graph TD
       A[GitHub Actions] -->|Authenticate| B[OIDC Auth Role]
       B -->|Assume| C[GitHub Workflows Role]
   ```

   ```yaml
   # filepath: .github/workflows/example.yml
   - name: Configure AWS credentials
     uses: aws-actions/configure-aws-credentials@v2
     with:
       role-to-assume: arn:aws:iam::$ACCOUNT_ID:role/aidoc-devops2-ex-github-oidc-auth
   ```

2. **GitHub Workflows Role**

   ```mermaid
   graph TD
       A[GitHub Workflows Role] -->|Push| B[ECR]
       A -->|Deploy| C[Infrastructure]
       A -->|Access| D[State Files]
   ```

   ```yaml
   # filepath: .github/workflows/example.yml
   - name: Assume Workflows Role
     run: |
       aws sts assume-role \
         --role-arn arn:aws:iam::$ACCOUNT_ID:role/aidoc-devops2-ex-github-actions-workflows \
         --role-session-name "GitHubActionsSession"
   ```

3. **State Manager Role**

   ```mermaid
   graph TD
       A[Developer] -->|Assume| B[State Manager Role]
       B -->|Manage| C[State Files]
       B -->|Lock| D[DynamoDB]
   ```

   ```bash
   # Local development
   export AWS_PROFILE=state-manager
   terraform state list
   terraform state show aws_lambda_function.example
   ```

4. **Terraform Role**

   ```mermaid
   graph TD
       A[Developer] -->|Assume| B[Terraform Role]
       B -->|Deploy| C[Infrastructure]
   ```

   ```bash
   # Local development
   export AWS_PROFILE=terraform
   terraform plan
   terraform apply
   ```

5. **SOPS Role**

   ```mermaid
   graph TD
       A[Developer/CI] -->|Assume| B[SOPS Role]
       B -->|Decrypt| C[Secrets]
   ```

   ```bash
   # Local development
   export AWS_PROFILE=sops
   sops -d secrets.yaml
   ```

## How to use test the Lambda Functions

Assuming the whole environment up and running.

### Order-Verfication

First, we need to create some sample data in the dynamodb table `orders`.

This can be done by running the following command:

It basically creates the sample order I was given as part of the assignment instructions, it's built differently in the table than the original sample data I was given but I'll elaborate n it in the next interview.

```bash
aws dynamodb put-item \
    --table-name orders \
    --item '{
        "partitionKey": {"S": "P001#johndoe@example.com"},
        "sortKey": {"S": "Wireless Mouse"},
        "orderId": {"S": "123456"},
        "customerName": {"S": "John Doe"},
        "customerEmail": {"S": "johndoe@example.com"},
        "orderDate": {"S": "2025-01-01T12:00:00Z"},
        "items": {"L": [
            {
                "M": {
                    "productId": {"S": "P001"},
                    "productName": {"S": "Wireless Mouse"},
                    "quantity": {"N": "2"},
                    "price": {"N": "25.99"}
                }
            }
        ]}
    }'
```

This is the original data sample from the instructions:

```json
{
  "orderId": "123456",
  "customerName": "John Doe",
  "customerEmail": "johndoe@example.com",
  "orderDate": "2025-01-01T12:00:00Z",
  "items": [
    {
      "productId": "P001",
      "productName": "Wireless Mouse",
      "quantity": 2,
      "price": 25.99
    }
  ]
}
```

And the payload we'll use in order to test the function.

First, run the following command to live-tail the lambda function's CloudWatch log group and stream:

```bash
aws logs start-live-tail \
    --log-group-identifiers "arn:aws:logs:AWS_REGION:AWS_ACCOUNT:log-group:/aws/lambda/order_verification" \
    --region AWS_REGION
```

Place that payload in a `.json` file and upload it to the `ordering-system s3 bucket`.

```bash
aws s3 cp ./test-data.json s3://ordering-system/orders/test-data.json
```

This is an example of expected output:

```log
aws logs start-live-tail \
    --log-group-identifiers "arn:aws:logs:eu-north-1:912466608750:log-group:/aws/lambda/order_verification" \
    --region eu-north-1
INIT_START Runtime Version: python:3.9.v64      Runtime Version ARN: arn:aws:lambda:eu-north-1::runtime:57e9dce4a928fd5b7bc1015238a5bc8a9146f096d69571fa4219ed8a2e76bfdf

21-Jan-25 17:42 [INFO] botocore.credentials - Found credentials in environment variables.

START RequestId: 84aad4e3-2105-4a30-9f30-9cbbde9924ca Version: $LATEST

21-Jan-25 17:42 [INFO] order_verification - Lambda function has been triggered.

21-Jan-25 17:42 [INFO] order_verification - Received event: {"Records": [{"eventVersion": "2.1", "eventSource": "aws:s3", "awsRegion": "eu-north-1", "eventTime": "2025-01-21T17:42:31.857Z", "eventName": "ObjectCreated:Put", "userIdentity": {"principalId": "AWS:AIDA5I4Z7QJXCAFX76XOI"}, "requestParameters": {"sourceIPAddress": "77.139.204.87"}, "responseElements": {"x-amz-request-id": "4JJ2HABSE74J673Q", "x-amz-id-2": "mhDN3f1/qA5cleNP1CqTaQqE29kjUz/lyy76bt/r9LVWKbAAmL4tEVAhMpaCsEATfO1fA9C6L5aR+wTGgFpw9SZbvKp9abTJ"}, "s3": {"s3SchemaVersion": "1.0", "configurationId": "tf-s3-lambda-20250120165216968800000001", "bucket": {"name": "ordering-system", "ownerIdentity": {"principalId": "A2UA6VIGPXS3UP"}, "arn": "arn:aws:s3:::ordering-system"}, "object": {"key": "orders/test1.json", "size": 253, "eTag": "163a4026b3c68ee83b1eb8c3e4fe0ff6", "sequencer": "00678FDC87A7C6DA82"}}}]}

21-Jan-25 17:42 [INFO] order_verification - Extracted bucket: ordering-system, object key: orders/test1.json

21-Jan-25 17:42 [INFO] order_verification - Attempting to retrieve file: orders/test1.json from bucket: ordering-system

21-Jan-25 17:42 [INFO] order_verification - Successfully retrieved file orders/test1.json from bucket ordering-system.

21-Jan-25 17:42 [INFO] order_verification - Parsed order data: {'orderId': '123456', 'customerName': 'John Doe', 'customerEmail': 'johndoe@example.com', 'orderDate': '2025-01-01T12:00:00Z', 'items': [{'productId': 'P001', 'productName': 'Wireless Mouse', 'quantity': 2, 'price': 25.99}]}

21-Jan-25 17:42 [INFO] order_verification - Validating order: {'orderId': '123456', 'customerName': 'John Doe', 'customerEmail': 'johndoe@example.com', 'orderDate': '2025-01-01T12:00:00Z', 'items': [{'productId': 'P001', 'productName': 'Wireless Mouse', 'quantity': 2, 'price': 25.99}]}

21-Jan-25 17:42 [INFO] order_verification - Item with productId P001 and productName Wireless Mouse exists.

21-Jan-25 17:42 [INFO] order_verification - Sending order to SQS: {'orderId': '123456', 'customerName': 'John Doe', 'customerEmail': 'johndoe@example.com', 'orderDate': '2025-01-01T12:00:00Z', 'items': [{'productId': 'P001', 'productName': 'Wireless Mouse', 'quantity': 2, 'price': 25.99}]}

21-Jan-25 17:42 [INFO] order_verification - Order 123456 successfully sent to SQS queue.

21-Jan-25 17:42 [INFO] order_verification - Order 123456 is valid and sent to SQS.

END RequestId: 84aad4e3-2105-4a30-9f30-9cbbde9924ca

REPORT RequestId: 84aad4e3-2105-4a30-9f30-9cbbde9924ca  Duration: 686.23 ms     Billed Duration: 687 ms Memory Size: 128 MB     Max Memory Used: 86 MB  Init Duration: 539.62 ms
```

Upload another `.json` file with incorrect details and this would be the expected output:

```log
START RequestId: c6ab3a4e-a0c9-4a00-a0cd-20047a1fb35c Version: $LATEST

21-Jan-25 17:57 [INFO] order_verification - Lambda function has been triggered.

21-Jan-25 17:57 [INFO] order_verification - Received event: {"Records": [{"eventVersion": "2.1", "eventSource": "aws:s3", "awsRegion": "eu-north-1", "eventTime": "2025-01-21T17:57:17.344Z", "eventName": "ObjectCreated:Put", "userIdentity": {"principalId": "AWS:XXXXXXXXXX"}, "requestParameters": {"sourceIPAddress": "77.139.204.87"}, "responseElements": {"x-amz-request-id": "X0V5P3FJP25V64GW", "x-amz-id-2": "7GHA3/kDaoZGIGXW7zxnAJahfu5UE5KjpWQ2MoRzX/A03Nm0KHCNVLALeC430voWWbiJK/CSa/4CJQvyPWF6FQBg21w7+DVKci0lSr/9TsA="}, "s3": {"s3SchemaVersion": "1.0", "configurationId": "tf-s3-lambda-20250120165216968800000001", "bucket": {"name": "ordering-system", "ownerIdentity": {"principalId": "XXXXXXXXXX"}, "arn": "arn:aws:s3:::ordering-system"}, "object": {"key": "orders/test2.json", "size": 312, "eTag": "6889a37bc968c1b1a11ac7b949aaf360", "sequencer": "00678FDFFD36B0C4B6"}}}]}

21-Jan-25 17:57 [INFO] order_verification - Extracted bucket: ordering-system, object key: orders/test2.json

21-Jan-25 17:57 [INFO] order_verification - Attempting to retrieve file: orders/test2.json from bucket: ordering-system

21-Jan-25 17:57 [INFO] order_verification - Successfully retrieved file orders/test2.json from bucket ordering-system.

21-Jan-25 17:57 [INFO] order_verification - Parsed order data: {'orderId': '999', 'customerName': 'John Doe', 'customerEmail': 'johndoe@example.com', 'orderDate': '2025-01-01T12:00:00Z', 'items': [{'productId': 'P006', 'productName': 'Headphones', 'quantity': 2, 'price': 25.99}]}

21-Jan-25 17:57 [INFO] order_verification - Validating order: {'orderId': '999', 'customerName': 'John Doe', 'customerEmail': 'johndoe@example.com', 'orderDate': '2025-01-01T12:00:00Z', 'items': [{'productId': 'P006', 'productName': 'Headphones', 'quantity': 2, 'price': 25.99}]}

21-Jan-25 17:57 [WARNING] order_verification - No matching items found for order 999.

21-Jan-25 17:57 [ERROR] order_verification - Order 999 is invalid.

END RequestId: c6ab3a4e-a0c9-4a00-a0cd-20047a1fb35c

REPORT RequestId: c6ab3a4e-a0c9-4a00-a0cd-20047a1fb35c  Duration: 473.17 ms     Billed Duration: 474 ms Memory Size: 128 MB     Max Memory Used: 85 MB  Init Duration: 531.54 ms
```

### Order-Retrieval

Run the following command to test the lambda:

API_KEY is provided in my email.

```bash
curl -X POST \
  "https://jqi77pe2bhrsopxfe673icqx6m0blqtw.lambda-url.eu-north-1.on.aws/process" \
  -H "x-api-key: API_KEY" \
  -H "Content-Type: application/json"
```

I've made sure the SQS queue that receives data, is populated with some test data (becuase my code also deletes the messages it processes).

Here's an example:

```bash
curl -X POST \
  "https://jqi77pe2bhrsopxfe673icqx6m0blqtw.lambda-url.eu-north-1.on.aws/process" \
  -H "x-api-key: API_KEY" \
  -H "Content-Type: application/json"
{"order":{"customerEmail":"johndoe@example.com","customerName":"Itai Doe","items":[{"price":25.99,"productId":"P001","productName":"Wireless Mouse","quantity":2},{"price":45.0,"productId":"P002","productName":"Keyboard","quantity":1}],"orderDate":"2025-01-01T12:00:00Z","orderId":"123456"}}
```

And this is a the function log:

```log
POST

/

content-type:application/x-amz-json-1.0

host:sqs.eu-north-1.amazonaws.com

x-amz-date:20250121T180843Z

x-amz-security-token:IQoJb3JpZ2luX2VjEMr//////////wEaCmV1LW5vcnRoLTEiRzBFAiEAmi+jujd6CCA2rPswMZepwJkHWdT9MQvHMGSI1igepwoCIA91/Tt5ct0B6YMrugwTpquL2KuB/5zTqSavE1WBnAFLKvwCCMP//////////wEQABoMOTEyNDY2NjA4NzUwIgzwVMJm96vjIyR0NL8q0AKT2LzLLplYyXYgBNyY1sIHJ5MTog3zkgTxmszvRenXbbI91LzxKdzfS/XjUdPej/m/Iph9o0g+anfsBS0U4+OX6UUFSuaRduw2AopjlcayvqqaUA9xuYjOrzSSWqPpoRO4aFEmO8W0KJ715qPjCS3d6di/WY1l4frOTMkRh8d7jf3CFt1SNrT42UUIn8tn5iTJjarNAKjhaU4Ux0v55HPzM4NRkOM0cYvsscNyg0x6faKG68Q0ZeXfYGYS5jlz/hnc6Z6YqEch9PHMefpJ/0KW3MgDSgxfoDErjf68WfOh2zjeG2blfCJ5CWuAV+kYX3w9Ndg8vGW7ZVOUjfZGLu7BSni7FRLmuOmjtrdvJLBxRiC27EsKLO8K+sb9ssVqMpMhLgqnNEoPoXwG57rQ9TKUM9vVlU/xOZt0PNaj1krkuWPhhkE8CTiG+tkxvddOZBcwzMK/vAY6ngHLpCdVm2rmN0wM5A/ACD15jl1ZxF0++n9CMQ0tu843L4gIJ+Iy+cDUZD4bClqcpTBxKpTBFrrizMgIvu5ZBVK2bUhSxX/kJWMHL3eksaquWTIAJGtuo1UGdOYXK+qkeW5c5EwZXgwTni22q/pj/sjPB1fGTgnAMq80Jq4ug0HPttBawq6jxUsVZ64Fk/jsRE2A6OsD/pHi5Mz81ej2uw==

x-amz-target:AmazonSQS.DeleteMessage

x-amzn-query-mode:true

content-type;host;x-amz-date;x-amz-security-token;x-amz-target;x-amzn-query-mode

1991f5eaa4f70f27b81d8e88c6d364cef26ffaad31e41f1e7e38fa4eb12c2a36

21-Jan-25 18:08 [DEBUG] botocore.auth - StringToSign:

AWS4-HMAC-SHA256

20250121T180843Z

20250121/eu-north-1/sqs/aws4_request

00be2b143df327c2add2a0665f590455745f97d5856e52e3d7a7c4b74a44bef0

21-Jan-25 18:08 [DEBUG] botocore.auth - Signature:

82db694a3bff2a695f1fe4aff361eb2e18257021da0df89864c9a22a0e0b0f3f

21-Jan-25 18:08 [DEBUG] botocore.hooks - Event request-created.sqs.DeleteMessage: calling handler <function add_retry_headers at 0x7fe4dde44f40>

21-Jan-25 18:08 [DEBUG] botocore.endpoint - Sending http request: <AWSPreparedRequest stream_output=False, method=POST, url=https://sqs.eu-north-1.amazonaws.com/, headers={'X-Amz-Target': b'AmazonSQS.DeleteMessage', 'Content-Type': b'application/x-amz-json-1.0', 'User-Agent': b'Boto3/1.35.92 md/Botocore#1.35.92 ua/2.0 os/linux#5.10.227-239.884.amzn2.x86_64 md/arch#x86_64 lang/python#3.11.10 md/pyimpl#CPython exec-env/AWS_Lambda_python3.11 cfg/retry-mode#legacy Botocore/1.35.92', 'X-Amzn-Trace-Id': b'Root=1-678fe2ab-234b0b7f6fbac3d12851ac0d;Parent=6d02e3384a64f2f5;Sampled=0;Lineage=1:4ce16fa3:0', 'x-amzn-query-mode': b'true', 'X-Amz-Date': b'20250121T180843Z', 'X-Amz-Security-Token': b'IQoJb3JpZ2luX2VjEMr//////////wEaCmV1LW5vcnRoLTEiRzBFAiEAmi+jujd6CCA2rPswMZepwJkHWdT9MQvHMGSI1igepwoCIA91/Tt5ct0B6YMrugwTpquL2KuB/5zTqSavE1WBnAFLKvwCCMP//////////wEQABoMOTEyNDY2NjA4NzUwIgzwVMJm96vjIyR0NL8q0AKT2LzLLplYyXYgBNyY1sIHJ5MTog3zkgTxmszvRenXbbI91LzxKdzfS/XjUdPej/m/Iph9o0g+anfsBS0U4+OX6UUFSuaRduw2AopjlcayvqqaUA9xuYjOrzSSWqPpoRO4aFEmO8W0KJ715qPjCS3d6di/WY1l4frOTMkRh8d7jf3CFt1SNrT42UUIn8tn5iTJjarNAKjhaU4Ux0v55HPzM4NRkOM0cYvsscNyg0x6faKG68Q0ZeXfYGYS5jlz/hnc6Z6YqEch9PHMefpJ/0KW3MgDSgxfoDErjf68WfOh2zjeG2blfCJ5CWuAV+kYX3w9Ndg8vGW7ZVOUjfZGLu7BSni7FRLmuOmjtrdvJLBxRiC27EsKLO8K+sb9ssVqMpMhLgqnNEoPoXwG57rQ9TKUM9vVlU/xOZt0PNaj1krkuWPhhkE8CTiG+tkxvddOZBcwzMK/vAY6ngHLpCdVm2rmN0wM5A/ACD15jl1ZxF0++n9CMQ0tu843L4gIJ+Iy+cDUZD4bClqcpTBxKpTBFrrizMgIvu5ZBVK2bUhSxX/kJWMHL3eksaquWTIAJGtuo1UGdOYXK+qkeW5c5EwZXgwTni22q/pj/sjPB1fGTgnAMq80Jq4ug0HPttBawq6jxUsVZ64Fk/jsRE2A6OsD/pHi5Mz81ej2uw==', 'Authorization': b'AWS4-HMAC-SHA256 Credential=ASIA5I4Z7QJXDIWB7VSL/20250121/eu-north-1/sqs/aws4_request, SignedHeaders=content-type;host;x-amz-date;x-amz-security-token;x-amz-target;x-amzn-query-mode, Signature=82db694a3bff2a695f1fe4aff361eb2e18257021da0df89864c9a22a0e0b0f3f', 'amz-sdk-invocation-id': b'88482ed6-5347-4b46-9c26-0a7ae36dce69', 'amz-sdk-request': b'attempt=1', 'Content-Length': '514'}>

21-Jan-25 18:08 [DEBUG] botocore.httpsession - Certificate path: /var/lang/lib/python3.11/site-packages/certifi/cacert.pem

21-Jan-25 18:08 [DEBUG] urllib3.connectionpool - https://sqs.eu-north-1.amazonaws.com:443 "POST / HTTP/1.1" 200 0

21-Jan-25 18:08 [DEBUG] botocore.parsers - Response headers: {'x-amzn-RequestId': '290db8ed-905f-53c9-a8b6-d8e474b45bfd', 'Date': 'Tue, 21 Jan 2025 18:08:43 GMT', 'Content-Type': 'application/x-amz-json-1.0', 'Content-Length': '0', 'connection': 'keep-alive'}

21-Jan-25 18:08 [DEBUG] botocore.parsers - Response body:

b''

21-Jan-25 18:08 [DEBUG] botocore.hooks - Event needs-retry.sqs.DeleteMessage: calling handler <botocore.retryhandler.RetryHandler object at 0x7fe4dcc237d0>

21-Jan-25 18:08 [DEBUG] botocore.retryhandler - No retry needed.

21-Jan-25 18:08 [INFO] order_retrieval - Order 123456 processed successfully

END RequestId: c3d0f17e-268c-48b6-86be-f7ced4f60cf8

REPORT RequestId: c3d0f17e-268c-48b6-86be-f7ced4f60cf8  Duration: 139.71 ms     Billed Duration: 140 ms Memory Size: 128 MB     Max Memory Used: 95 MB
```
