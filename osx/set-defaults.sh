#!/usr/bin/env bash

# ~/.macos — https://mths.be/macos
osascript -e 'tell application "System Preferences" to quit'

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until `.osx` has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Disable the sound effects on boot
echo -e "Disable the sound effects on boot \n"
nvram SystemAudioVolume=" "

# Set standby delay to 24 hours (default is 1 hour)
echo -e "Set standby delay to 24 hours (default is 1 hour) \n"
pmset -a standbydelay 86400

# Disable guest account login
echo -e "Disable guest account login \n"
defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false

# Require password immediately after sleep or screen saver
echo -e "Require password immediately after sleep or screen saver \n"
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Increase window resize speed for Cocoa applications
echo -e "Increase window resize speed for Cocoa applications \n"
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Set a blazingly fast keyboard repeat rate
echo -e "Set a blazingly fast keyboard repeat rate \n"
defaults write NSGlobalDomain KeyRepeat -int 0

# Set up Safari for development
echo -e "Set up Safari for development \n"
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" -bool true
defaults write -g WebKitDeveloperExtras -bool true

# Prevent Safari from opening ‘safe’ files automatically after downloading
echo -e "Prevent Safari from opening ‘safe’ files automatically after downloading \n"
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

# Set Safari’s home page to `about:blank` for faster loading
echo -e "Set Safari’s home page to `about:blank` for faster loading \n"
defaults write com.apple.Safari HomePage -string "about:blank"

# Use AirDrop over every interface
echo -e "Use AirDrop over every interface \n"
defaults write com.apple.NetworkBrowser BrowseAllInterfaces 1

# Disable the “Are you sure you want to open this application?” dialog
echo -e "Disable the “Are you sure you want to open this application?” dialog \n"
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Always open everything in Finder's List view
echo -e "Always open everything in Finder's List view. This is important \n"
defaults write com.apple.Finder FXPreferredViewStyle Nlsv

# Show all filename extensions
echo -e "Show all filename extensions \n"
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Disable the warning when changing file extensions
echo -e "Disable the warning when changing file extensions \n"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Allow text-selection in Quick Look
echo -e "Allow text-selection in Quick Look \n"
defaults write com.apple.finder QLEnableTextSelection -bool true

# Disable press-and-hold for keys in favor of key repeat.
echo -e "Disable press-and-hold for keys in favor of key repeat \n"
defaults write -g ApplePressAndHoldEnabled -bool false

# Finder: show path bar
echo -e "Finder: show path bar \n"
defaults write com.apple.finder ShowPathbar -bool true

# Automatically hide and show the Dock
echo -e "Automatically hide and show the Dock \n"
defaults write com.apple.dock autohide -bool true

# Reveal IP address, hostname, OS version, etc. when clicking the clock
# in the login window
echo -e "Reveal IP address, hostname, OS version, etc. when clicking the clock in the login window \n"
sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName

# Disable smart quotes as they’re annoying when typing code
echo -e "Disable smart quotes as they’re annoying when typing code \n"
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Increase sound quality for Bluetooth headphones/headsets
echo -e "Increase sound quality for Bluetooth headphones/headsets \n"
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Max (editable)" -int 80
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 48
defaults write com.apple.BluetoothAudioAgent "Apple Initial Bitpool (editable)" -int 40
defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool" -int 48
defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool Max" -int 53
defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool Min" -int 48
defaults write com.apple.BluetoothAudioAgent "Stream – Flush Ring on Packet Drop (editable)" -int 30
defaults write com.apple.BluetoothAudioAgent "Stream – Max Outstanding Packets (editable)" -int 15


###############################################################################
# Do some clean up work.
###############################################################################

for app in "Activity Monitor" "Address Book" "Calendar" "Contacts" "cfprefsd" \
           "Dock" "Finder" "Mail" "Messages" "Safari" "SystemUIServer" \
           "Twitter" "iCal" "bluetoothaudiod"; do
           killall "${app}" > /dev/null 2>&1
done

# Wait a bit before moving on...
sleep 1

# ...and then.
echo "Success! Defaults are set."
echo "Some changes will not take effect until you reboot your machine."