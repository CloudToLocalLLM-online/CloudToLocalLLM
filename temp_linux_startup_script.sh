#!/bin/bash
sudo apt-get update
sudo apt-get install -y git curl

mkdir /actions-runner
cd /actions-runner

curl -o actions-runner-linux-x64-$(arch).tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-$(arch).tar.gz
tar xzf ./actions-runner-linux-x64-$(arch).tar.gz

./config.sh --url https://github.com/imrightguy --token BOBH5XEA7XJPPTNW2CYI7F3IUR2RG --labels linux,self-hosted --unattended

sudo ./svc.sh install
sudo ./svc.sh start