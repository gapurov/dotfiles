#!/usr/bin/env bash

# ~/.macos — https://mths.be/macos
osascript -e 'tell application "System Preferences" to quit'

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until `.osx` has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

###############################################################################
# General UI/UX                                                               #
###############################################################################

# Disable the sound effects on boot
echo -e "\033[1m\033[34m==> Disable the sound effects on boot \033[0m \n"
nvram SystemAudioVolume=" "

# Set standby delay to 24 hours (default is 1 hour)
echo -e "\033[1m\033[34m==> Set standby delay to 24 hours (default is 1 hour) \033[0m \n"
pmset -a standbydelay 86400

# Disable guest account login
echo -e "\033[1m\033[34m==> Disable guest account login \033[0m \n"
defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false

# Increase window resize speed for Cocoa applicatio ns
echo -e "\033[1m\033[34m==> Increase window resize speed for Cocoa applications \033[0m \n"
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Prevent Safari from opening ‘safe’ files automatically after downloading
echo -e "\033[1m\033[34m==> Prevent Safari from opening ‘safe’ files automatically after downloading \033[0m \n"
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

# Set Safari’s home page to `about:blank` for faster loading
echo -e "\033[1m\033[34m==> Set Safari’s home page to `about:blank` for faster loading \033[0m \n"
defaults write com.apple.Safari HomePage -string "about:blank"

# Use AirDrop over every interface
echo -e "\033[1m\033[34m==> Use AirDrop over every interface \033[0m \n"
defaults write com.apple.NetworkBrowser BrowseAllInterfaces 1

# Expand save panel by default
echo -e "\033[1m\033[34m==> Expand save panel by default \033[0m \n"
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Disable the “Are you sure you want to open this application?” dialog
echo -e "\033[1m\033[34m==> Disable the “Are you sure you want to open this application?” dialog \033[0m \n"
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Always open everything in Finder's List view
echo -e "\033[1m\033[34m==> Always open everything in Finder's List view. This is important \033[0m \n"
defaults write com.apple.Finder FXPreferredViewStyle Nlsv

# Show all filename extensions
echo -e "\033[1m\033[34m==> Show all filename extensions \033[0m \n"
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Disable the warning when changing file extensions
echo -e "\033[1m\033[34m==> Disable the warning when changing file extensions \033[0m \n"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Finder: show path bar
echo -e "\033[1m\033[34m==> Finder: show path bar \033[0m \n"
defaults write com.apple.finder ShowPathbar -bool true

# Finder: Keep folders on top when sorting by name
echo -e "\033[1m\033[34m==> Finder: Keep folders on top when sorting by name \033[0m \n"
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Automatically hide and show the Dock
echo -e "\033[1m\033[34m==> Automatically hide and show the Dock \033[0m \n"
defaults write com.apple.dock autohide -bool true

# Enable Safari’s debug menu
echo -e "\033[1m\033[34m==> Enable Safari’s debug menu \033[0m \n"
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true

# Disable smart quotes as they’re annoying when typing code
echo -e "\033[1m\033[34m==> Disable smart quotes as they’re annoying when typing code \033[0m \n"
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Mail.app: Add the keyboard shortcut ⌘ + Enter to send an email in Mail.app
echo -e "\033[1m\033[34m==> Mail.app: Add the keyboard shortcut ⌘ + Enter to send an email in Mail.app \033[0m \n"
defaults write com.apple.mail NSUserKeyEquivalents -dict-add "Send" "@\U21a9"

# Mail.app: Display emails in threaded mode, sorted by date (oldest at the top)
echo -e "\033[1m\033[34m==> Mail.app: Display emails in threaded mode, sorted by date (oldest at the top) \033[0m \n"
defaults write com.apple.mail DraftsViewerAttributes -dict-add "DisplayInThreadedMode" -string "yes"
defaults write com.apple.mail DraftsViewerAttributes -dict-add "SortedDescending" -string "yes"
defaults write com.apple.mail DraftsViewerAttributes -dict-add "SortOrder" -string "received-date"

# Mail.app: Disable inline attachments (just show the icons)
echo -e "\033[1m\033[34m==> Mail.app: Disable inline attachments (just show the icons) \033[0m \n"
defaults write com.apple.mail DisableInlineAttachmentViewing -bool true

###############################################################################
# Trackpad, mouse, keyboard, Bluetooth accessories, and input                 #
###############################################################################

# Trackpad: enable tap to click for this user and for the login screen
echo -e "\033[1m\033[34m==> Trackpad: enable tap to click for this user and for the login screen \033[0m \n"
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Increase sound quality for Bluetooth headphones/headsets
echo -e "\033[1m\033[34m==> Increase sound quality for Bluetooth headphones/headsets \033[0m \n"
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Max (editable)" -int 80
defaults write com.apple.BluetoothAudioAgent "Apple Bitpool Min (editable)" -int 48
defaults write com.apple.BluetoothAudioAgent "Apple Initial Bitpool (editable)" -int 40
defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool" -int 48
defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool Max" -int 53
defaults write com.apple.BluetoothAudioAgent "Negotiated Bitpool Min" -int 48
defaults write com.apple.BluetoothAudioAgent "Stream – Flush Ring on Packet Drop (editable)" -int 30
defaults write com.apple.BluetoothAudioAgent "Stream – Max Outstanding Packets (editable)" -int 15

# Enable full keyboard access for all controls
# (e.g. enable Tab in modal dialogs)
echo -e "\033[1m\033[34m==> Enable full keyboard access for all controls \033[0m \n"
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Use scroll gesture with the Ctrl (^) modifier key to zoom
echo -e "\033[1m\033[34m==> Use scroll gesture with the Ctrl (^) modifier key to zoom \033[0m \n"
defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true
defaults write com.apple.universalaccess HIDScrollZoomModifierMask -int 262144
# Follow the keyboard focus while zoomed in
echo -e "\033[1m\033[34m==> Follow the keyboard focus while zoomed in \033[0m \n"
defaults write com.apple.universalaccess closeViewZoomFollowsFocus -bool true

# Disable press-and-hold for keys in favor of key repeat.
echo -e "\033[1m\033[34m==> Disable press-and-hold for keys in favor of key repeat \033[0m \n"
defaults write -g ApplePressAndHoldEnabled -bool false


# Set default languages...
echo -e "\033[1m\033[34m==> Set default languages... \033[0m \n"
defaults write NSGlobalDomain AppleLanguages "(en-DE, de-DE, ru-DE)";

# Show language menu in the top right corner of the boot screen
echo -e "\033[1m\033[34m==> Show language menu in the top right corner of the boot screen \033[0m \n"
sudo defaults write /Library/Preferences/com.apple.loginwindow showInputMenu -bool true


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