#!/usr/bin/env bash
#
# The script that the systemd service executes

export AWS_CONFIG_FILE=/home/ubuntu/.aws/config
export AWS_SHARED_CREDENTIALS_FILE=/home/ubuntu/.aws/credentials
cd /home/ubuntu/shopifyasst
./main.sh