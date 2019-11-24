#!/usr/bin/env bash 

# The following steps will create an ECS cluster on AWS
# This process assumes you have an AWS account with the AWS CLI installed locally
# It will ask you which VPC and Subnets to use

# Show the commands being executed and exit if there is a problem
set -ex

# AWS Region to use
REGION=us-east-1
# Key Pair name to create
KEY_PAIR_NAME=example
# ECS optimized AMI
AMI_ID=ami-097e3d1cdb541f43e

#
# No need to change anything beyond this point
#

# List existing VPCs in the region
aws ec2 describe-vpcs --region ${REGION} --query 'Vpcs[*].VpcId'

# Read in the users VPC choice
echo "please chose the VPC to use:"
read VPC_ID

# Create a key pair and save a local copy as a pem file
aws ec2 create-key-pair --key-name ${KEY_PAIR_NAME} --region ${REGION} --query 'KeyMaterial' --output text > ${KEY_PAIR_NAME}.pem

# Create EC2 instance Security Group, it will return its security group ID
aws ec2 create-security-group --region ${REGION} --group-name instances-sg --description "For EC2 instances"

# Create an Application Load Balancer Security Group, it will return its security group ID
aws ec2 create-security-group --region ${REGION} --group-name alb-sg --description "For the ALBs"

echo "Please enter your Instance security group:"
read INSTANCE_SG

echo "Please enter your ALB security group:"
read ALB_SG

# List existing Subnets in the chosen VPC
aws ec2 describe-subnets --region ${REGION} --query 'Subnets[*].SubnetId' --filters "Name=vpc-id,Values=${VPC_ID}"

# Read in the users Subnet choice
echo "Please enter 2 different Subnet IDs to use from the above list:"
read SUBNET_ID_1
read SUBNET_ID_2

# Add rule to the security group to allow port 80 open to all
aws ec2 authorize-security-group-ingress --region ${REGION} --group-name instances-sg --to-port 80 --ip-protocol tcp --cidr-ip 0.0.0.0/0 --from-port 80
aws ec2 authorize-security-group-ingress --region ${REGION} --group-name alb-sg --to-port 80 --ip-protocol tcp --cidr-ip 0.0.0.0/0 --from-port 80

# Add rule to let the ALB SG in to the instances SG
aws ec2 authorize-security-group-ingress --region ${REGION} --group-name instances-sg --protocol tcp --port 1-65535 --source-group alb-sg

# Create an ALB with 2 Subnets
aws elbv2 create-load-balancer --region ${REGION} --name example-load-balancer --security-groups ${ALB_SG} --subnets ${SUBNET_ID_1} ${SUBNET_ID_2}

# Get the ARN of the ALB we just created
ALB_ARN=`aws elbv2 describe-load-balancers --region ${REGION} --names "example-load-balancer" --query 'LoadBalancers[*].[LoadBalancerArn]'  --output text`

# Create a Target Group
aws elbv2 create-target-group --region ${REGION} --name example-targets --protocol HTTP --port 80 --target-type instance --vpc-id ${VPC_ID}

# Get the ARN of the Target group we just created
TG_ARN=`aws elbv2 describe-target-groups --region ${REGION} --names "example-targets" --query 'TargetGroups[*].[TargetGroupArn]' --output text`

# Create an ALB listener
aws elbv2 create-listener \
    --load-balancer-arn ${ALB_ARN} \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=${TG_ARN} \
    --region ${REGION}

# Create the cluster
aws ecs create-cluster --cluster-name example --region ${REGION}

# Create container instance, this is just an EC2 instance that is part of an ECS Cluster and has docker and the ecs-agent running on it.
aws ec2 run-instances --image-id ${AMI_ID} --count 1 \
--instance-type t2.micro --key-name ${KEY_PAIR_NAME} \
--subnet-id ${SUBNET_ID_1} --security-group-ids ${INSTANCE_SG} \
--iam-instance-profile Arn=arn:aws:iam::016230046494:instance-profile/ecsInstanceRole \
--user-data file://data.txt \
--region ${REGION} \
--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=example}]'

# Create Task Definition - Describes how a docker container should launch. It contains settings like ports, docker image, cpu, memory, command to run and env variables.
aws ecs register-task-definition --cli-input-json file://definition.json --region ${REGION}

# Update the service.json file to include the Target Group ARN
sed -i "s/TARGET_GROUP_ARN/${TG_ARN//\//\\/}/g" service.json.template > service.json

# Create the Service responsible for maintaining the tasks
aws ecs create-service --cli-input-json file://service.json --region ${REGION}

# Query the LB to get its public DNS
aws elbv2 describe-load-balancers --region ${REGION} --load-balancer-arns ${ALB_ARN}--query 'LoadBalancers[*].[DNSName]' --output text

# Open the DNSName in your web browser to see your running container output - might take a few seconds
