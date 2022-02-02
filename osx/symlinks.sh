#!/usr/bin/env bash

# Set a Symlink for the Sublime Merge to be accessible vie `smerge`
echo -e "Set a Symlink for the Sublime Merge to be accessible via '$ smerge' \n"
ln -sf "/Applications/Sublime Merge.app/Contents/SharedSupport/bin/smerge" /usr/local/bin/smerge
