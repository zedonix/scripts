#!/bin/bash

sudo snapper -c root create-config /
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
sudo systemctl enable --now grub-btrfsd
