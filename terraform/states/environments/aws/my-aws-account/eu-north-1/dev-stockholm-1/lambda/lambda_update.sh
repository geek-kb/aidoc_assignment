#!/bin/bash
#!/bin/bash
set -e

# Variables
AWS_ACCOUNT="912466608750"
AWS_REGION="eu-north-1"
ECR_REPO="order-retrieval"
LAMBDA_FUNCTION="order_retrieval"

# Build and push
docker build -t ${ECR_REPO} .
docker tag ${ECR_REPO}:latest ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest
docker push ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest

# Get latest image digest
IMAGE_DIGEST=$(aws ecr describe-images \
  --repository-name ${ECR_REPO} \
  --query 'sort_by(imageDetails,& imagePushedAt)[-1].imageDigest' \
  --output text)

# Update Lambda
aws lambda update-function-code \
  --function-name ${LAMBDA_FUNCTION} \
  --image-uri ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}@${IMAGE_DIGEST}

# Wait for update
aws lambda wait function-updated --function-name ${LAMBDA_FUNCTION}

echo "Deployment complete"
