#!/bin/bash
BUILDER_NAME="ie-project"

# Check if the builder already exists
if docker buildx ls | grep -q "$BUILDER_NAME"; then
  echo "Builder '$BUILDER_NAME' already exists. Using it..."
  docker buildx use "$BUILDER_NAME"
  docker buildx inspect --bootstrap > /dev/null
else
  echo "Builder '$BUILDER_NAME' does not exist. Creating and using it..."
  docker buildx create --name "$BUILDER_NAME" --use --bootstrap
fi

cd terraform
terraform init
terraform apply -auto-approve
cd ..