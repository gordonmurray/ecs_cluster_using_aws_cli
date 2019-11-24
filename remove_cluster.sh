#!/usr/bin/env bash 

# Remove the ECS cluster items
# This process assumes you have an AWS account with the AWS CLI installed locally


# Show the commands being executed and exit if there is a problem
set -ex

# AWS region
REGION="us-east-1"
# Key Pair name
KEY_PAIR_NAME=example

# Get the instance ID of the EC2 instance
INSTANCE_ID=`aws ec2 describe-instances --filter "Name=tag:Name,Values=example" --region ${REGION} --query 'Reservations[].Instances[].[InstanceId]' --output text`

# delete the EC2 instance
aws ec2 terminate-instances --region ${REGION} --instance-ids ${INSTANCE_ID}

# delete the ALB
ALB_ARN=`aws elbv2 describe-load-balancers --region ${REGION} --names "example-load-balancer" --query 'LoadBalancers[*].[LoadBalancerArn]'  --output text`
ALB_LISTENER_ARN=`aws elbv2 describe-listeners --load-balancer-arn ${ALB_ARN} --query 'Listeners[*].[ListenerArn]' --region ${REGION} --output text`

aws elbv2 delete-listener --listener-arn ${ALB_LISTENER_ARN} --region ${REGION}
aws elbv2 delete-load-balancer --load-balancer-arn ${ALB_ARN} --region ${REGION}

# delete the Target Group
TG_ARN=`aws elbv2 describe-target-groups --region ${REGION} --names "example-targets" --query 'TargetGroups[*].[TargetGroupArn]' --output text`
aws elbv2 delete-target-group --target-group-arn ${TG_ARN}

# delete security group
aws ec2 delete-security-group --region ${REGION} --group-name instances-sg
aws ec2 delete-security-group --region ${REGION} --group-name alb-sg

# scale service to 0
aws ecs update-service --cluster example --service my-service --desired-count 0 --region ${REGION}

# delete services
aws ecs delete-service --cluster example --service my-service

# delete the ecs cluster
aws ecs delete-cluster --cluster example --region ${REGION}

# delete the key pair from AWS
aws ec2 delete-key-pair --region ${REGION} --key-name ${KEY_PAIR_NAME}

# delete the key pair from the local folder
rm ${KEY_PAIR_NAME}.pem 
