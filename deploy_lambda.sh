#!/bin/bash


RED=31
GREEN=32
YELLOW=33

coloredEcho() {
    local color=$1
    shift
    echo -e "\e[${color}m$@\e[0m"
}

# check for any command errors and log the line where error occurred in the script
set -e
trap 'coloredEcho $RED "ERROR: script failed at line $LINENO"' ERR

# Load environment variables/AWS Secrets from .env file
if [ -f .env ]; then
    source .env
else
    coloredEcho $RED ".env file not found"
    exit 1
fi

IMAGE_NAME="test-lambda-function"
IMAGE_TAG="test"
ECR_REPO_NAME="test-lambda-ecr"
LAMBDA_FUNCTION_NAME="test-lambda-function"
ROLE_NAME="lambda-execution"
TIMEOUT=30


# authenticate docker cli in your machine to AWS ECR
aws ecr get-login-password --region "$AWS_REGION" --profile "$AWS_PROFILE" | docker login --username AWS --password-stdin "$AWS_ACCOUNT_NUMBER".dkr.ecr."$AWS_REGION".amazonaws.com

# Check if the repository already exists
if aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    coloredEcho $YELLOW "Repository $ECR_REPO_NAME already exists. Skipping creation.\n"
else
    # creates a ECR repository in your account if not exists - update the ecr repo name if desired
    coloredEcho $YELLOW "Creating ECR Repo...\n"
    aws ecr create-repository --repository-name "$ECR_REPO_NAME" --region "${AWS_REGION}" --image-scanning-configuration scanOnPush=true --image-tag-mutability MUTABLE
    coloredEcho $YELLOW "Success: repo created\n"
fi


coloredEcho $YELLOW "building image and tagging for ECR...\n"

# build the image containing our lambda python code - update the tag name if desired
docker build --platform linux/amd64 -t "${IMAGE_NAME}:${IMAGE_TAG}" .

ECR_URI=$(aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "${AWS_REGION}" --query 'repositories[0].repositoryUri' --output text)
# Copy your lambda docker image to the ECR Repo
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "$ECR_URI":latest

# push image to ECR
docker push "$ECR_URI":latest

coloredEcho $YELLOW "Success: pushed image to ECR: $ECR_URI:latest\n"

# Create a execution role for the lambda (uses file that should hold the trust policy and is adjacent to this script)
coloredEcho $YELLOW "Creating execution role and attaching basic execution permissions to the role...\n"

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
    coloredEcho $YELLOW "Role $ROLE_NAME already exists. Updating role...\n"

    ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)

    # Update the assume role policy document
    aws iam update-assume-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-document file://trust-policy.json

    coloredEcho $YELLOW "Updated assume role policy for $ROLE_NAME\n"
else
    coloredEcho $YELLOW "Creating Role $ROLE_NAME...\n"
    
    ROLE_ARN=$(aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file://trust-policy.json \
    --query 'Role.Arn' \
    --output text)

    coloredEcho $YELLOW "Role $ROLE_NAME created successfully\n"
fi

coloredEcho $YELLOW "Attaching AWSLambdaBasicExecutionRole permissions...\n"

aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

coloredEcho $YELLOW "Success: Role setup complete\n"

# Create or Update the Lambda function:
if aws lambda get-function --function-name "$LAMBDA_FUNCTION_NAME" --output text >/dev/null 2>&1; then
    coloredEcho $YELLOW "Function already exists. Updating function...\n"

    aws lambda update-function-code \
      --function-name "$LAMBDA_FUNCTION_NAME" \
      --image-uri "$ECR_URI":latest

    coloredEcho $YELLOW "Waiting for function update to complete..."

    # Wait for the function to be in an updateable state - there is a cooldown period between updates to lambda you need to wait for
    aws lambda wait function-updated --function-name "$LAMBDA_FUNCTION_NAME"
        
    aws lambda update-function-configuration \
      --function-name "$LAMBDA_FUNCTION_NAME" \
      --timeout "$TIMEOUT"


    coloredEcho $YELLOW "\n SUCCESS: Lambda function updated"
else
    coloredEcho $YELLOW "Creating Lambda Function $LAMBDA_FUNCTION_NAME...\n"
    # NOTE: need to set the timeout higher potentially for cold starts!!
    aws lambda create-function \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --package-type Image \
    --code ImageUri="$ECR_URI":latest \
    --role "$ROLE_ARN" \
    --timeout "$TIMEOUT"

    coloredEcho $YELLOW "SUCCESS: Lambda created\n"
fi
