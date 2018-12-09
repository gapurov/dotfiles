#!/usr/bin/env bash

# Workaround for the Annoying shortcut Beep Sound in VSCODE on MacOSX
# https://gist.github.com/gapurov/e59bd0735073e907c0b98c9e77d468f3

noop='{
    "^@\UF701" = "noop:";
    "^@\UF702" = "noop:";
    "^@\UF703" = "noop:";
}'

mkdir -p ~/Library/KeyBindings/
touch ~/Library/KeyBindings/DefaultKeyBinding.dict
echo $noop >> ~/Library/KeyBindings/DefaultKeyBinding.dict