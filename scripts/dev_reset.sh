#!/usr/bin/env bash
set -euo pipefail

# DANGER: This script deletes AWS resources matching the prefix.
# Intended for demo/dev cleanup only.

REGION="${AWS_REGION:-us-east-1}"
PREFIX="${PREFIX:-agentic-sre-dev}"
CONFIRM="${CONFIRM_DELETE_PREFIX:-}"

if [[ -z "${CONFIRM}" || "${CONFIRM}" != "${PREFIX}" ]]; then
  echo "Refusing to run. Set CONFIRM_DELETE_PREFIX=${PREFIX} to confirm destructive cleanup." >&2
  exit 1
fi

AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text --region "${REGION}")"
echo "Cleanup start: account=${AWS_ACCOUNT_ID} region=${REGION} prefix=${PREFIX}"

log_group="/${PREFIX}/ecs"

echo "Deleting CloudWatch log group (if exists): ${log_group}"
aws logs delete-log-group --log-group-name "${log_group}" --region "${REGION}" 2>/dev/null || true

echo "Deleting Secrets Manager secrets (if exist): ${PREFIX}/*"
secret_names=(openai_api_key groq_api_key grafana_api_key slack_webhook jira_token github_token redis_auth_token)
for s in "${secret_names[@]}"; do
  aws secretsmanager delete-secret \
    --secret-id "${PREFIX}/${s}" \
    --force-delete-without-recovery \
    --region "${REGION}" 2>/dev/null || true
done

echo "Deleting SNS topic (if exists): ${PREFIX}-alerts"
topic_arn="$(aws sns list-topics --region "${REGION}" --query "Topics[?ends_with(TopicArn,':${PREFIX}-alerts')].TopicArn | [0]" --output text 2>/dev/null || true)"
if [[ -n "${topic_arn}" && "${topic_arn}" != "None" ]]; then
  aws sns delete-topic --topic-arn "${topic_arn}" --region "${REGION}" || true
fi

echo "Deleting ECS services/cluster (if exists): ${PREFIX}-cluster"
cluster_name="${PREFIX}-cluster"
if aws ecs describe-clusters --clusters "${cluster_name}" --region "${REGION}" --query "clusters[0].status" --output text >/dev/null 2>&1; then
  # scale down + delete services
  services="$(aws ecs list-services --cluster "${cluster_name}" --region "${REGION}" --query "serviceArns[]" --output text 2>/dev/null || true)"
  for svc in ${services}; do
    aws ecs update-service --cluster "${cluster_name}" --service "${svc}" --desired-count 0 --region "${REGION}" >/dev/null 2>&1 || true
    aws ecs delete-service --cluster "${cluster_name}" --service "${svc}" --force --region "${REGION}" >/dev/null 2>&1 || true
  done
  # attempt cluster delete (may take time if services are still draining)
  aws ecs delete-cluster --cluster "${cluster_name}" --region "${REGION}" >/dev/null 2>&1 || true
fi

echo "Deleting IAM roles (if exist): ${PREFIX}-ecs-task, ${PREFIX}-ecs-task-exec"
roles=("${PREFIX}-ecs-task" "${PREFIX}-ecs-task-exec")
for role in "${roles[@]}"; do
  if aws iam get-role --role-name "${role}" >/dev/null 2>&1; then
    # detach managed policies
    attached="$(aws iam list-attached-role-policies --role-name "${role}" --query "AttachedPolicies[].PolicyArn" --output text 2>/dev/null || true)"
    for arn in ${attached}; do
      aws iam detach-role-policy --role-name "${role}" --policy-arn "${arn}" >/dev/null 2>&1 || true
    done
    # delete inline policies
    inline="$(aws iam list-role-policies --role-name "${role}" --query "PolicyNames[]" --output text 2>/dev/null || true)"
    for pname in ${inline}; do
      aws iam delete-role-policy --role-name "${role}" --policy-name "${pname}" >/dev/null 2>&1 || true
    done
    aws iam delete-role --role-name "${role}" >/dev/null 2>&1 || true
  fi
done

echo "Attempting VPC cleanup (best effort): tag Name=${PREFIX}-vpc"
vpc_id="$(aws ec2 describe-vpcs --region "${REGION}" --filters "Name=tag:Name,Values=${PREFIX}-vpc" --query "Vpcs[0].VpcId" --output text 2>/dev/null || true)"
if [[ -n "${vpc_id}" && "${vpc_id}" != "None" ]]; then
  echo "Found VPC: ${vpc_id}"

  # Delete NAT gateways (wait until deleted)
  nat_ids="$(aws ec2 describe-nat-gateways --region "${REGION}" --filter "Name=vpc-id,Values=${vpc_id}" --query "NatGateways[?State!='deleted'].NatGatewayId" --output text 2>/dev/null || true)"
  for nat in ${nat_ids}; do
    aws ec2 delete-nat-gateway --nat-gateway-id "${nat}" --region "${REGION}" >/dev/null 2>&1 || true
  done

  # Detach and delete internet gateways
  igw_ids="$(aws ec2 describe-internet-gateways --region "${REGION}" --filters "Name=attachment.vpc-id,Values=${vpc_id}" --query "InternetGateways[].InternetGatewayId" --output text 2>/dev/null || true)"
  for igw in ${igw_ids}; do
    aws ec2 detach-internet-gateway --internet-gateway-id "${igw}" --vpc-id "${vpc_id}" --region "${REGION}" >/dev/null 2>&1 || true
    aws ec2 delete-internet-gateway --internet-gateway-id "${igw}" --region "${REGION}" >/dev/null 2>&1 || true
  done

  # Delete subnets
  subnet_ids="$(aws ec2 describe-subnets --region "${REGION}" --filters "Name=vpc-id,Values=${vpc_id}" --query "Subnets[].SubnetId" --output text 2>/dev/null || true)"
  for sn in ${subnet_ids}; do
    aws ec2 delete-subnet --subnet-id "${sn}" --region "${REGION}" >/dev/null 2>&1 || true
  done

  # Delete non-main route tables
  rtb_ids="$(aws ec2 describe-route-tables --region "${REGION}" --filters "Name=vpc-id,Values=${vpc_id}" --query "RouteTables[?Associations[?Main==\`true\`]|length(@)==\`0\`].RouteTableId" --output text 2>/dev/null || true)"
  for rtb in ${rtb_ids}; do
    aws ec2 delete-route-table --route-table-id "${rtb}" --region "${REGION}" >/dev/null 2>&1 || true
  done

  # Delete security groups (skip default)
  sg_ids="$(aws ec2 describe-security-groups --region "${REGION}" --filters "Name=vpc-id,Values=${vpc_id}" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text 2>/dev/null || true)"
  for sg in ${sg_ids}; do
    aws ec2 delete-security-group --group-id "${sg}" --region "${REGION}" >/dev/null 2>&1 || true
  done

  # Release tagged EIP (best effort)
  alloc_id="$(aws ec2 describe-addresses --region "${REGION}" --filters "Name=tag:Name,Values=${PREFIX}-nat-eip" --query "Addresses[0].AllocationId" --output text 2>/dev/null || true)"
  if [[ -n "${alloc_id}" && "${alloc_id}" != "None" ]]; then
    aws ec2 release-address --allocation-id "${alloc_id}" --region "${REGION}" >/dev/null 2>&1 || true
  fi

  # Finally delete VPC
  aws ec2 delete-vpc --vpc-id "${vpc_id}" --region "${REGION}" >/dev/null 2>&1 || true
fi

echo "Cleanup done (best effort). If VPC deletion failed, check for remaining dependencies and retry."

