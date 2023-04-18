#!/usr/bin/env bash

function installPackages() {
  jq -r '.dependencies | to_entries | .[] | if .value == "latest-version" then .key else .key + "@" + .value end'  $HOME/.dotfiles/javascript/package.json | \

  while read -r key; do
      corepack npm install --location=global $key
  done
}

function setNodePageManager() {
  corepack enable
  corepack prepare yarn@1.22.11 --activate
  corepack prepare pnpm@latest --activate
}

# install node first
fnm install 16
fnm install 18
fnm install 19

# install packages for v16
fnm default 16
setNodePageManager
installPackages

# install packages for v18 and set it to default
fnm default 18
setNodePageManager
installPackages
