#!/bin/bash

# JAVA path
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=/usr/lib/jvm/java-17-openjdk-amd64/bin:"$PATH"

# aws access variables 
aws_access_key_id=
aws_secret_access_key=
aws_session_token=

# docker access variables
yourDockerUsername=
yourDockerPassword=

# exporting all variables to be used by next scripts
export AWS_ACCESS_KEY_ID=$aws_access_key_id
export AWS_SECRET_ACCESS_KEY=$aws_secret_access_key
export AWS_SESSION_TOKEN=$aws_session_token
export DockerUsername=$yourDockerUsername
export DockerPassword=$yourDockerPassword


