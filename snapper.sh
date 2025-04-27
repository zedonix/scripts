#!/bin/bash

sudo snapper -c root create-config /
sudo systemctl enable snapper-timeline.timer
sudo systemctl enable snapper-cleanup.timer
sudo systemctl enable grub-btrfsd
