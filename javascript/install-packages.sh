#!/usr/bin/env bash

# install node first
fnm install 19
fnm install 18
fnm install 16

jq -r '.dependencies | to_entries | .[] | if .value == "latest-version" then .key else .key + "@" + .value end'  $HOME/.dotfiles/javascript/package.json | \

while read -r key; do
    npm install --location=global $key
done
