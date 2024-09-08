#!/bin/bash -e

export CDK_PARAM_SYSTEM_ADMIN_EMAIL="dummy"


export REGION=$(aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]')  # Region setting
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create S3 Bucket for provision source.
source ./update-provision-source.sh

echo "CDK_PARAM_COMMIT_ID exists: $CDK_PARAM_COMMIT_ID"

# Create ECS service linked role.
aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com 2>/dev/null || echo "ECS Service linked role exists"

# Preprovision basic infrastructure
cd ../server

sed "s/<REGION>/$REGION/g; s/<ACCOUNT_ID>/$ACCOUNT_ID/g" ./service-info.txt > ./lib/service-info.json

# npx cdk bootstrap
export CDK_PARAM_ONBOARDING_DETAIL_TYPE='Onboarding'
export CDK_PARAM_PROVISIONING_DETAIL_TYPE=$CDK_PARAM_ONBOARDING_DETAIL_TYPE
export CDK_PARAM_OFFBOARDING_DETAIL_TYPE='Offboarding'
export CDK_PARAM_DEPROVISIONING_DETAIL_TYPE=$CDK_PARAM_OFFBOARDING_DETAIL_TYPE
export CDK_PARAM_TIER='basic'
export CDK_PARAM_STAGE='prod'

export CDK_BASIC_CLUSTER="$CDK_PARAM_STAGE-$CDK_PARAM_TIER"

npm install
npx cdk bootstrap

npx cdk diff tenant-template-stack-basic > ./diff_output.txt 2>&1
if grep -q "There were no differences" ./diff_output.txt; then
    echo "No changes detected in the tenant-template-stack-basic."
else
    echo "Changes detected in the tenant-template-stack-basic."

    SERVICES=$(aws ecs list-services --cluster $CDK_BASIC_CLUSTER --query 'serviceArns[*]' --output text || true)
    for SERVICE in $SERVICES; do
        SERVICE_NAME=$(echo $SERVICE | rev | cut -d '/' -f 1 | rev)

        echo -n "==== Service Connect Disable: "
        aws ecs update-service \
            --cluster $CDK_BASIC_CLUSTER \
            --service $SERVICE_NAME \
            --service-connect-configuration 'enabled=false' \
            --no-cli-pager --query 'service.serviceArn' --output text
        
    done
fi
rm diff_output.txt


npx cdk deploy shared-infra-stack --require-approval=never
npx cdk deploy \
    tenant-template-stack-basic \
    tenant-template-stack-advanced --require-approval=never
