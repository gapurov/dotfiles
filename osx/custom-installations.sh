#!/usr/bin/env bash

# Tea
echo "installing tea.xyz"
sh <(curl https://tea.xyz)

# bun
echo "installing bun"
curl -fsSL https://bun.sh/install | bash # for macOS, Linux, and WSL
