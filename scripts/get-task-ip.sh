#!/bin/bash

export SERVICE_NAME="$1"

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <service-name>"
    exit 1
fi

CLUSTER_NAME=$(aws ecs list-clusters --query 'clusterArns[*]' --output json | jq -r '.[] | select(contains("/prod-advanced-")) | split("/") | .[1]') 

# Step 1: Get the Task ARN
TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --query 'taskArns[0]' --output text)

# Check if TASK_ARN is empty
if [ -z "$TASK_ARN" ]; then
    echo "No tasks found for service $SERVICE_NAME in cluster $CLUSTER_NAME"
    exit 1
fi

# Step 2: Get the ENI ID
export PRIVATE_IP=$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN --query 'tasks[0].attachments[?type==`ElasticNetworkInterface`][].details[?name==`privateIPv4Address`].value | [0]' --output text)

# Output the Private IP
echo "Private IP: $PRIVATE_IP"