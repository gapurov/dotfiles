#!/usr/bin/env bash

# install node first
volta install node@16

jq -r '.dependencies | to_entries | .[] | if .value == "latest-version" then .key else .key + "@" + .value end'  $HOME/.dotfiles/javascript/package.json | \

while read -r key; do
    # npm install -g $key
    volta install $key
done
