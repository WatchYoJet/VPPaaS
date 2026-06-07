aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=terraform-kafka-account1-9d30a412" \
            "Name=vpc-id,Values=vpc-0f6830e709b47ddbc" \
  --query 'SecurityGroups[0].GroupId' \
  --output text


terraform -chdir=terraform/Account1/Kafka import aws_security_group.instance sg-XXXX

ssh-keygen -y -f ~/.ssh/labsuser.pem > /tmp/vockey.pub
aws ec2 import-key-pair --key-name vockey --public-key-material fileb:///tmp/vockey.pub


terraform -chdir=terraform/Account1/Kafka apply \
  -replace='null_resource.kafkaClusterSetup[0]' \
  -replace='null_resource.kafkaClusterSetup[1]' \
  -replace='null_resource.kafkaClusterSetup[2]'