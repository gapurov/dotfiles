#!/usr/bin/env bash

# install node first
fnm install 16.19
fnm install 18.14
fnm install 19.6

# install node package manager
corepack enable
corepack prepare yarn@1.22.11 --activate
corepack prepare pnpm@latest --activate

jq -r '.dependencies | to_entries | .[] | if .value == "latest-version" then .key else .key + "@" + .value end'  $HOME/.dotfiles/javascript/package.json | \

while read -r key; do
    corepack npm install --location=global $key
done
