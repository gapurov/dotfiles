#!/usr/bin/env bash

export VOLTA_HOME="$HOME/.volta" && rm -rf $VOLTA_HOME && (
  curl https://get.volta.sh | bash -s -- --skip-setup
)