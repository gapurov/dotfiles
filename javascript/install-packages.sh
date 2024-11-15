#!/usr/bin/env bash

function installPackages() {
  jq -r '.dependencies | to_entries | .[] | if .value == "latest-version" then .key else .key + "@" + .value end'  $HOME/.dotfiles/javascript/package.json | \

  while read -r key; do
      bun i -g $key
      # corepack npm install --location=global $key
  done
}

function setNodePackageManagers() {
  corepack enable
  corepack prepare yarn@1.22.11 --activate
  corepack prepare pnpm@latest --activate
}

# upgrade bun
bun upgrade

# install node first
fnm install 20
fnm install 21

# install packages for v20
fnm default 21
setNodePackageManagers

# install packages for v18 and set it to default
fnm default 20
setNodePackageManagers

# install packages
installPackages
