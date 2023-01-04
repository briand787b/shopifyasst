# Uploader for CityStock Shopify App

## Description
This script is meant to upload images to Shopify and all dependent third-party plugins.  Once installed on a VM in AWS EC2, this script will cycle through the `citystock-uploader-kevin` bucket, create a Shopify product from the image metadata, upload the asset to the third-party plugin, and then link the asset to the Shopify product.  The shell script that uploads images will only work on a Linux machine.  The installation instructions below only apply to Ubuntu, but may be applicable to any Unix-like system that has the `exiftool` available.

## Installation
### Create VM
We will create a VM to perform the uploads for two reasons.  The first is that a pristine runtime environment is easier to guarantee on a dedicated VM than it would be on a contributor's personal machine.  The second is that the VM is in the AWS network and thus has extremely fast connectivity.

Inside of the AWS console, create an EC2 instance:
* Name: uploader (NOTE: if you change this, ensure that the change is reflected in later steps that use 'INSTANCE_NAME')
* Image: Ubuntu 22.04 (or higher)
* SSH Keys: `brians_gram`
* VPC: Cluster-VPC
* Subnet: Public-Subnet-1
* Auto-Assign Public IP: Enable
* Security Group: ssh-anywhere

Inside of the AWS console, create an IAM user for the EC2 instance:
* Access Type: Programmatic access
* Name: uploader
* Role: S3-Admin
* Region: us-east-1 (used in `aws configure`)

### Set Up VM
From host:
```bash
INSTANCE_NAME='uploader'
INSTANCES="$(aws ec2 describe-instances --filters Name=tag:Name,Values="$INSTANCE_NAME")"
INSTANCE_IP_ADDR="$(echo $INSTANCES | jq '.Reservations[0].Instances[0].PublicIpAddress' | tr -d '"')"
ssh -i ~/.ssh/brians_gram.pem ubuntu@$INSTANCE_IP_ADDR
```

From VM:
```bash
sudo apt update
sudo apt upgrade -y
sudo reboot
# log back in as before
sudo apt install exiftool awscli golang python3.10-venv python3-pip
aws configure # provide access key and pw from console
# clone repo
git clone git@github.com:briand787b/shopifyasst.git
cd shopifyasst
# set up secret env vars
cp example.env .env # fill in secret values
# install py deps.  You may want to create a venv before this
cd py
python -m venv venv # optional
source py/venv/bin/activate
pip install -r py/requirements.txt
```

## How to Run
```bash
# if you did not compile go binary yet
./main.sh --recompile

# otherwise
./main.sh
```