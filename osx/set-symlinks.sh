#!/usr/bin/env bash

# Set a Symlink in the $HOME to the iCloud folder
echo -e "Set a Symlink in the \$HOME to the iCloud folder \n"
ln -sf ~/Library/Mobile\ Documents/com~apple~CloudDocs ~/iCloud

# Set a Symlink for the Sublime Merge to be accessible vie `smerge`
echo -e "Set a Symlink for the Sublime Merge to be accessible via '$ smerge' \n"
ln -sf "/Applications/Sublime Merge.app/Contents/SharedSupport/bin/smerge" /usr/local/bin/smerge