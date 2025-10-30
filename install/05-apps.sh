#!/bin/bash

# Load package lists
BASE_PACKAGES=$(cat ../packages/base.txt)

# Install
sudo pacman -S --needed $BASE_PACKAGES