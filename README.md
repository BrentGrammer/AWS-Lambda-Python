# AWS Lambda with Python Deployment package

Example project to deploy a Python deployment package (zip file) to AWS Lambda with dependencies included.

- [AWS Docs - zipping a python package](https://docs.aws.amazon.com/lambda/latest/dg/python-package.html)
- [Example worflow using version control](https://stackoverflow.com/questions/78157777/how-to-package-and-deploy-aws-python-lambda-functions-automatically)

## Prerequisites

- Docker
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html)
  - Configure with `aws configure [--profile {profilename}]`
    - Be sure to use the profile in the deploy_lambda.sh aws commands if provided

## Setup to containerize the Lambda

- **Use Docker**: The AWS Lambda needs the dependencies to be built with the same instruction set architecture and Operating System compatible with it.
  - See [AWS Docs - Packages with containers](https://docs.aws.amazon.com/lambda/latest/dg/python-image.html)
  - [Testing locally with an AWS image](https://gallery.ecr.aws/lambda/python)
  - If you build/install dependencies on Windows or Mac this could cause issues when the code runs in the AWS Lambda.
  - Use Docker container to match the OS and environment with the Lambda so that when you build your python package, it is compatible.

## Steps

- [See AWS Docs for using AWS Base images](https://docs.aws.amazon.com/lambda/latest/dg/python-image.html)
- Create requirements.txt to define what dependencies are needed for the package
- Create a Dockerfile

### Use a base image from AWS:

- Copy a dockerfile example from the AWS docs for the image

### Test your lambda in the container locally

- build the image `docker build --platform linux/amd64 -t docker-image:test .`
- run the image `docker run --platform linux/amd64 -p 9000:8080 docker-image:test`
- in a new terminal test hitting the docker hosted function with: `curl "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{}'`
- After done kill the container with: `docker kill {ID}`

### For building a deployment package using the docker container:

- see [Video](https://www.youtube.com/watch?v=ojG-oGmsGZo)
- Create a `docker_install.sh` shell script to install python packages and make the folder a module with **init**.py
- Create a `runner.sh` script to start the docker container and build the deployment package in the container env (to match the AWS Lambda runtime and prevent errors), and copy the zip produced to your local machine so you can upload it to the lambda.

## Deploying the Lambda

- Make sure Environment variables are set in a `.env` file:
  - AWS_ACCOUNT_NUMBER={AWS account num that will have access to the Lambda}
  - AWS_REGION={region that the Lambda will be created in: i.e. us-east-1}
  - AWS_PROFILE={name of the profile you created with `aws configure --profile` which holds your AWS credentials}

- `chmod +x deploy_lambda.sh`
- run `./deploy_lambda.sh`

## Github Actions

- Example templates: https://github.com/serverless/github-action
