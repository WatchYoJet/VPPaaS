#!/bin/bash
set -e

BASE_AMI="ami-07ff62358b87c7116"
KEY_NAME="vockey"

create_ami() {
  local account=$1       # "Account 1" or "Account 2"
  local env_key=$2       # "ACCOUNT1_AMI" or "ACCOUNT2_AMI"
  local sg_suffix=$3     # "account1" or "account2"
  local pem_file=$4      # "labsuser.pem" or "labsuser2.pem"

  echo ""
  echo "=== Creating Docker Base AMI for $account ==="

  local SG_NAME="temp-ami-builder-${sg_suffix}-$(date +%s)"

  echo "--- Creating temporary security group ---"
  local SG_ID
  SG_ID=$(aws ec2 create-security-group \
    --group-name "$SG_NAME" \
    --description "Temp SG for AMI creation" \
    --query 'GroupId' --output text)

  aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp --port 22 --cidr 0.0.0.0/0

  echo "--- Launching temp EC2 ---"
  local INSTANCE_ID
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$BASE_AMI" \
    --instance-type "t3.small" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SG_ID" \
    --query 'Instances[0].InstanceId' \
    --output text)

  echo "Instance ID: $INSTANCE_ID - waiting for running..."
  aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

  local PUBLIC_DNS
  PUBLIC_DNS=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicDnsName' \
    --output text)

  echo "Waiting for SSH at $PUBLIC_DNS ..."
  until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
      -i "$pem_file" ec2-user@"$PUBLIC_DNS" "echo ready" 2>/dev/null; do
    echo -n "."
    sleep 10
  done
  echo " SSH ready!"

  echo "--- Installing Docker ---"
  ssh -o StrictHostKeyChecking=no -i "$pem_file" ec2-user@"$PUBLIC_DNS" \
    "sudo yum install -y docker && sudo systemctl enable docker && sudo service docker start"

  echo "--- Cleaning cloud-init state so new instances boot cleanly ---"
  ssh -o StrictHostKeyChecking=no -i "$pem_file" ec2-user@"$PUBLIC_DNS" \
    "sudo cloud-init clean --logs && sudo rm -f /etc/cloud/cloud.cfg.d/99-fake-cloud.cfg"

  local AMI_NAME="vppas-docker-base-${sg_suffix}-$(date +%Y%m%d-%H%M)"
  echo "--- Creating AMI: $AMI_NAME ---"
  local AMI_ID
  AMI_ID=$(aws ec2 create-image \
    --instance-id "$INSTANCE_ID" \
    --name "$AMI_NAME" \
    --no-reboot \
    --query 'ImageId' \
    --output text)

  echo "AMI ID: $AMI_ID - waiting for availability (2-5 min)..."
  aws ec2 wait image-available --image-ids "$AMI_ID"
  echo "AMI ready!"

  echo "--- Terminating temp instance ---"
  aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" > /dev/null
  aws ec2 wait instance-terminated --instance-ids "$INSTANCE_ID"
  aws ec2 delete-security-group --group-id "$SG_ID"

  # Write or update amis.env
  if grep -q "^${env_key}=" amis.env 2>/dev/null; then
    sed -i "s|^${env_key}=.*|${env_key}=${AMI_ID}|" amis.env
  else
    echo "${env_key}=${AMI_ID}" >> amis.env
  fi

  echo "$account AMI saved: $AMI_ID"
}

# Account 1
source access.sh
create_ami "Account 1" "ACCOUNT1_AMI" "account1" "$HOME/.ssh/labsuser.pem"

# Account 2
source access2.sh
create_ami "Account 2" "ACCOUNT2_AMI" "account2" "$HOME/.ssh/labsuser2.pem"

echo ""
echo "; Both AMIs created and saved to amis.env"
echo "Next: ./Deploy.sh"
