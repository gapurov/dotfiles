#!/usr/bin/env bash
set -euo pipefail

# Close System Settings / old System Preferences if open (name changed in Ventura)
osascript -e 'tell application "System Settings" to quit' 2>/dev/null || true
osascript -e 'tell application "System Preferences" to quit' 2>/dev/null || true

# Sudo keepalive (only if not managed by caller)
if [[ "${DOTFILES_SUDO_ACTIVE:-0}" != "1" ]]; then
  sudo -v
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
fi

###############################################################################
# General UI/UX                                                               #
###############################################################################

# Startup chime: mute at boot (more reliable than SystemAudioVolume on modern Macs)
echo -e "\033[1m\033[34m==> Disable the startup chime \033[0m\n"
sudo nvram StartupMute=%01  || true  # %00 to re-enable

# Standby delay ~ 24h (use low/high keys on modern macOS; fallback if unsupported)
echo -e "\033[1m\033[34m==> Set standby delay to ~24h \033[0m\n"
if pmset -g | grep -q standbydelayhigh; then
  sudo pmset -a standby 1
  sudo pmset -a standbydelaylow  86400
  sudo pmset -a standbydelayhigh 86400
else
  sudo pmset -a standbydelay 86400 || true
fi

# Disable guest account login (supported way)
echo -e "\033[1m\033[34m==> Disable guest account login \033[0m\n"
sudo sysadminctl -guestAccount off || true

# Faster window resize animations
echo -e "\033[1m\033[34m==> Speed up window resize animations \033[0m\n"
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Finder & Safari basics
echo -e "\033[1m\033[34m==> Finder & Safari preferences \033[0m\n"
# Finder
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"   # List view
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Safari
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false
defaults write com.apple.Safari HomePage -string "about:blank"
# Modern replacement for old hidden Debug menu: show Develop menu
defaults write com.apple.Safari IncludeDevelopMenu -bool true

# Save panel expanded by default
echo -e "\033[1m\033[34m==> Expand save panel by default \033[0m\n"
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode  -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Dock tweaks
echo -e "\033[1m\033[34m==> Configure Dock \033[0m\n"
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock orientation -string "left"
defaults write com.apple.dock autohide-delay -float 0.25
defaults write com.apple.dock autohide-time-modifier -float 0.30
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock showhidden -bool true  # transparent hidden apps

# Typing/auto-correct behaviors
echo -e "\033[1m\033[34m==> Typing & text input preferences \033[0m\n"
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled       -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled          -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled      -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled      -bool false
defaults write NSGlobalDomain NSAutomaticTextCompletionEnabled          -bool false
defaults write NSGlobalDomain WebAutomaticSpellingCorrectionEnabled     -bool false
defaults write -g ApplePressAndHoldEnabled -bool false
defaults write -g InitialKeyRepeat -int 15   # smaller = faster initial delay
defaults write -g KeyRepeat        -int 2    # smaller = faster repeat rate

# Keyboard focus & zoom
echo -e "\033[1m\033[34m==> Accessibility: keyboard focus & zoom \033[0m\n"
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true
defaults write com.apple.universalaccess HIDScrollZoomModifierMask -int 262144
defaults write com.apple.universalaccess closeViewZoomFollowsFocus -bool true

# Trackpad: tap to click (user + login window)
echo -e "\033[1m\033[34m==> Trackpad: enable tap to click \033[0m\n"
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain       com.apple.mouse.tapBehavior -int 1

# Languages (use valid BCP-47 codes and proper array syntax)
echo -e "\033[1m\033[34m==> Set preferred languages \033[0m\n"
defaults write NSGlobalDomain AppleLanguages -array "en-US" "de-DE" "ru-RU"

# Show input menu at login window
echo -e "\033[1m\033[34m==> Show input menu at login window \033[0m\n"
sudo defaults write /Library/Preferences/com.apple.loginwindow showInputMenu -bool true

# Mail.app tweaks
echo -e "\033[1m\033[34m==> Mail.app settings \033[0m\n"
# Cmd+Return to Send
defaults write com.apple.mail NSUserKeyEquivalents -dict-add "Send" "@\U21a9"
# Prefer icons instead of inline previews (works on many recent macOS versions)
defaults write com.apple.mail DisableInlineAttachmentViewing -bool true || true
# Threading options (Apple sometimes shuffles these; best-effort)
defaults write com.apple.mail DraftsViewerAttributes -dict-add "DisplayInThreadedMode" -string "yes"
defaults write com.apple.mail DraftsViewerAttributes -dict-add "SortedDescending"      -string "yes"
defaults write com.apple.mail DraftsViewerAttributes -dict-add "SortOrder"             -string "received-date"

# Optional: prune default Dock items if dockutil is installed
if command -v dockutil >/dev/null 2>&1; then
  echo -e "\033[1m\033[34m==> Removing default Dock apps with dockutil \033[0m\n"
  for label in \
    "Launchpad" "Safari" "Mail" "FaceTime" "Messages" "Maps" "Photos" "Contacts" \
    "Calendar" "Reminders" "Notes" "Music" "Podcasts" "TV" "News" "Numbers" \
    "Keynote" "Pages" "App Store" "System Settings" ; do
      dockutil --find "$label" >/dev/null 2>&1 && dockutil --remove "$label" || true
  done
fi

# Apply
killall Finder   >/dev/null 2>&1 || true
killall Dock     >/dev/null 2>&1 || true

echo "Success! Defaults are set. Some changes require logout/restart."
