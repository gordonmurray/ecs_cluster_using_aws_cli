# ECS cluster using the AWS CLI

A couple of scripts to create an AWS ECS cluster using the AWS CLI.

Use the cluster.sh script to start creating the cluster. It will ask you the VPC and Subnets to use. The end result it a working ECS cluster, with 1 small EC2 instance, running a simple Hello World PHP script

If you would like to change the container image that is deployed to the cluster, then create or update the definition.json file 

Use remove_cluster.sh if you'd like to remove the cluster after you're done with it.
