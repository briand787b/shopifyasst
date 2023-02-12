#!/usr/bin/env bash

sudo cp shopifyasst.service shopifyasst.timer /etc/systemd/system
sudo systemctl enable shopifyasst.timer
sudo systemctl start shopifyasst.timer