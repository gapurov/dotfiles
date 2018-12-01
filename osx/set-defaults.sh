#!/bin/bash

#
# Reasonably sets OS X defaults. My sources:
#  - https://github.com/skwp/dotfiles/blob/master/bin/osx
#  - https://github.com/mathiasbynens/dotfiles/blob/master/.osx
# ~/dotfiles/osx/set-defaults.sh — http://mths.be/osx
#

# Set computer name
COMPUTERNAME="Vladislav Gapurov's MBP"
HOSTNAME='gapurov_mbp'
LOCALHOSTNAME='gapurov_mbp'

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until `.osx` has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

###############################################################################
# General UI/UX                                                               #
###############################################################################

# Set computer name (as done via System Preferences → Sharing)
echo -e "Set computer name (as done via System Preferences → Sharing) \n"
sudo scutil --set ComputerName $COMPUTERNAME
sudo scutil --set HostName $HOSTNAME
sudo scutil --set LocalHostName $LOCALHOSTNAME
defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string $LOCALHOSTNAME

# Disable guest account login
echo -e "Disable guest account login \n"
defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false

###############################################################################
# Apple software: Safari, Updater, iTunes, etc.                               #
###############################################################################

# Hide Safari's bookmark bar
echo -e "Hide Safari's bookmark bar \n"
defaults write com.apple.Safari ShowFavoritesBar -bool false

# Set up Safari for development
echo -e "Set up Safari for development \n"
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" -bool true
defaults write -g WebKitDeveloperExtras -bool true

# Privacy: don’t send search queries to Apple
echo -e "Privacy: don’t send search queries to Apple \n"
defaults write com.apple.Safari UniversalSearchEnabled -bool false
defaults write com.apple.Safari SuppressSearchSuggestions -bool true

# Prevent Safari from opening ‘safe’ files automatically after downloading
echo -e "Prevent Safari from opening ‘safe’ files automatically after downloading \n"
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

# Set Safari’s home page to `about:blank` for faster loading
echo -e "Set Safari’s home page to `about:blank` for faster loading \n"
defaults write com.apple.Safari HomePage -string "about:blank"

# Use AirDrop over every interface
echo -e "Use AirDrop over every interface \n"
defaults write com.apple.NetworkBrowser BrowseAllInterfaces 1

# Check for software updates daily, not just once per week
echo -e "Check for software updates daily, not just once per week \n"
defaults write com.assple.SoftwareUpdate ScheduleFrequency -int 1

# Disable the “Are you sure you want to open this application?” dialog
echo -e "Disable the “Are you sure you want to open this application?” dialog \n"
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Disable Swipe controls for Google Chrome
# defaults write com.google.Chrome.plist AppleEnableSwipeNavigateWithScrolls -bool FALSE

# Disable inline attachments in Mail.app (just show the icons)
echo -e "Disable inline attachments in Mail.app (just show the icons) \n"
defaults write com.apple.mail DisableInlineAttachmentViewing -bool true

# Only use UTF-8 in Terminal.app
# defaults write com.apple.terminal StringEncodings -array 4

# Disable some menu bar icons: Time Machine, Volume and User
# for domain in ~/Library/Preferences/ByHost/com.apple.stytemuiserver.*; do
#   "/System/Library/CoreServices/Menu Extras/TimeMachine.menu" \
#   "/System/Library/CoreServices/Menu Extras/Volume.menu" \
#   "/System/Library/CoreServices/Menu Extras/User.menu"
# done

# Enable the WebKit Developer Tools in the Mac App Store
echo -e "Enable the WebKit Developer Tools in the Mac App Store \n"
defaults write com.apple.appstore WebKitDeveloperExtras -bool true

###############################################################################
# Activity Monitor                                                            #
###############################################################################

# Show the main window when launching Activity Monitor
echo -e "Show the main window when launching Activity Monitor \n"
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true

# Visualize CPU usage in the Activity Monitor Dock icon
echo -e "Visualize CPU usage in the Activity Monitor Dock icon \n"
defaults write com.apple.ActivityMonitor IconType -int 5

# Show all processes in Activity Monitor
echo -e "Show all processes in Activity Monitor \n"
defaults write com.apple.ActivityMonitor ShowCategory -int 0

# Sort Activity Monitor results by CPU usage
echo -e "Sort Activity Monitor results by CPU usage \n"
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

###############################################################################
# Interfaces: trackpad, mouse, keyboard, bluetooth, etc.
###############################################################################

# Map bottom right corner of Apple trackpad to right-click.
# defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2
# defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
# defaults -currentHost write -g com.apple.trackpad.trackpadCornerClickBehavior -int 1
# defaults -currentHost write com.apple.trackpad.enableSecondaryClick -bool true

# Disable 'natural' scrolling
echo -e "Disable 'natural' scrolling \n"
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# Set a really fast keyboard repeat rate
echo -e "Set a really fast keyboard repeat rate \n"
defaults write -g KeyRepeat -int 0
defaults write -g InitialKeyRepeat -int 10

# Disable press-and-hold for keys in favor of key repeat
echo -e "Disable press-and-hold for keys in favor of key repeat \n"
defaults write -g ApplePressAndHoldEnabled -bool false

# Set language and text formats. (USD and Imperial Units)
# defaults write -g AppleLanguages -array "en" "nl"
# defaults write -g AppleLocale -string "en_US@currency=USD"
# defaults write -g AppleMeasurementUnits -string "Inches"
# defaults write -g AppleMetricUnits -bool false

###############################################################################
# Screen
###############################################################################

# Hot corners
# Possible values:
#   0: no-op
#   2: Mission Control
#   3: Show application windows
#   4: Desktop
#   5: Start screen saver
#   6: Disable screen saver
#   7: Dashboard
#  10: Put display to sleep
#  11: Launchpad
#  12: Notification Center
# defaults write com.apple.dock wvous-bl-corner -int 5
# defaults write com.apple.dock wvous-bl-modifier -int 0

# Require password immediately after sleep or screen saver
echo -e "Require password immediately after sleep or screen saver \n"
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Save screenshots to desktop and disable the horrific drop-shadow
echo -e "Save screenshots to desktop and disable the horrific drop-shadow \n"
defaults write com.apple.screencapture location -string "${HOME}/Desktop/Screenshots"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# Enable sub-pixel rendering on non-Apple LCDs
echo -e "Enable sub-pixel rendering on non-Apple LCDs \n"
defaults write NSGlobalDomain AppleFontSmoothing -int 2

###############################################################################
# Finder
###############################################################################

# Disable and kill Dashboard
# Can be reverted with:
# defaults write com.apple.dashboard mcx-disabled -boolean NO; killall Doc
echo -e "Disable and kill Dashboard \n"
defaults write com.apple.dashboard mcx-disabled -boolean YES; killall Dock

# Disable icons on the Desktop
# This will "hide" all the files on the Desktop, but one can still access
# the files through Finder. Makes things look pretty.
# defaults write com.apple.finder CreateDesktop -bool false && killall Finder

# Allow quitting via ⌘ + Q; doing so will also hide desktop icons
echo -e "Allow quitting via ⌘ + Q; doing so will also hide desktop icons \n"
defaults write com.apple.finder QuitMenuItem -bool true

# Show the ~/Library folder
echo -e "Show the ~/Library folder \n"
chflags nohidden ~/Library

# Set the Finder prefs for showing a few different volumes on the Desktop
echo -e "Set the Finder prefs for showing a few different volumes on the Desktop \n"
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

# Always open everything in Finder's List view. This is important
# Flwv ▸ Cover Flow View
# Nlsv ▸ List View
# clmv ▸ Column View
# icnv ▸ Icon View
echo -e "Always open everything in Finder's List view. This is important \n"
defaults write com.apple.Finder FXPreferredViewStyle Nlsv

# Show status bar
echo -e "Show status bar \n"
defaults write com.apple.finder ShowStatusBar -bool true

# Show path bar
echo -e "Show path bar \n"
defaults write com.apple.finder ShowPathbar -bool true

# When performing a search, search the current folder by default
echo -e "When performing a search, search the current folder by default \n"
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Avoid creating .DS_Store files on network volumes
echo -e "Avoid creating .DS_Store files on network volumes \n"
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Don’t automatically rearrange Spaces based on most recent use
echo -e "Don’t automatically rearrange Spaces based on most recent use \n"
defaults write com.apple.dock mru-spaces -bool false

# Make Dock more transparent
echo -e "Make Dock more transparent \n"
defaults write com.apple.dock hide-mirror -bool true

# Show hidden files by default
# defaults write com.apple.finder AppleShowAllFiles -bool true

# Show all filename extensions
echo -e "Show all filename extensions \n"
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Disable the warning when changing file extensions
echo -e "Disable the warning when changing file extensions \n"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Allow text-selection in Quick Look
echo -e "Allow text-selection in Quick Look \n"
defaults write com.apple.finder QLEnableTextSelection -bool true

# Disable the warning before emptying the Trash
echo -e "Disable the warning before emptying the Trash \n"
defaults write com.apple.finder WarnOnEmptyTrash -bool false

# Enable auto-correct
echo -e "Enable auto-correct \n"
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool true

# Disable the “Are you sure you want to open this application?” dialog
echo -e "Disable the “Are you sure you want to open this application?” dialog \n"
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Expand print panel by default
echo -e "Expand print panel by default \n"
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true

# Expand save panel by default
echo -e "Expand save panel by default \n"
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true

# Disable Resume system-wide
echo -e "Disable Resume system-wide \n"
defaults write com.apple.systempreferences NSQuitAlwaysKeepsWindows -bool false

# Disable the crash reporter
echo -e "Disable the crash reporter \n"
defaults write com.apple.CrashReporter DialogType -string "none"

###############################################################################
# SSD
###############################################################################

# Disable the sudden motion sensor as it’s not useful for SSDs
echo -e "Disable the sudden motion sensor as it’s not useful for SSDs \n"
sudo pmset -a sms 0

###############################################################################
# Dock
###############################################################################

# Show indicator lights for open applications in the Dock
echo -e "Set up Safari for development \n"
defaults write com.apple.dock show-process-indicators -bool true

# Add several spacers
# defaults write com.apple.dock persistent-apps -array-add '{tile-data={}; tile-type="spacer-tile";}'
# defaults write com.apple.dock persistent-apps -array-add '{tile-data={}; tile-type="spacer-tile";}'
# defaults write com.apple.dock persistent-apps -array-add '{tile-data={}; tile-type="spacer-tile";}'
# defaults write com.apple.dock persistent-apps -array-add '{tile-data={}; tile-type="spacer-tile";}'

# Automatically hide and show the Dock
echo -e "Automatically hide and show the Dock \n"
defaults write com.apple.dock autohide -bool true

# Set Dock position to Left
echo -e "Set Dock orientation to 'left' \n"
defaults write com.apple.dock 'orientation' -string 'left'
 
###############################################################################
# Do some clean up work.
###############################################################################

for app in "Activity Monitor" "Address Book" "Calendar" "Contacts" "cfprefsd" \
           "Dock" "Finder" "Mail" "Messages" "Safari" "SystemUIServer" \
           "Terminal" "Twitter" "iCal"; do
           kill all "${app}" > /dev/null 2>&1
done

# Wait a bit before moving on...
sleep 1

# ...and then.
echo "Success! Defaults are set."
echo "Some changes will not take effect until you reboot your machine."

# See if the user wants to reboot.
function reboot() {
  read -p "Do you want to reboot your computer now? (y/N)" choice
  case "$choice" in
    y | Yes | yes ) echo "Yes"; exit;; # If y | yes, reboot
    n | N | No | no) echo "No"; exit;; # If n | no, exit
    * ) echo "Invalid answer. Enter \"y/yes\" or \"N/no\"" && return;;
  esac
}

# Call on the function
if [[ "Yes" == $(reboot) ]]
then
  echo "Rebooting."
  sudo reboot
  exit 0
else
  exit 1
fi