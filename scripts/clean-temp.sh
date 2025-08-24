#!/bin/bash
# Clean temporary files and caches from development environment

set -euo pipefail

echo "🧹 Cleaning temporary files and caches..."

cleaned_count=0

# Function to safely remove if exists
safe_remove() {
    local path="$1"
    local description="$2"

    if [[ -e "$path" ]]; then
        echo "🗑️  Removing $description"
        rm -rf "$path"
        ((cleaned_count++))
    fi
}

# Clean common temporary directories
safe_remove "$HOME/.cache" "user cache directory"
safe_remove "$HOME/.npm/_logs" "npm log files"
safe_remove "$HOME/.npm/_cacache" "npm cache"
safe_remove "$HOME/.node_repl_history" "Node.js REPL history"
safe_remove "$HOME/.python_history" "Python history"
safe_remove "$HOME/.lesshst" "less history"
safe_remove "$HOME/.viminfo" "Vim info file"

# Clean development tool caches
safe_remove "$HOME/Library/Caches/Homebrew" "Homebrew cache (macOS)"
safe_remove "$HOME/.composer/cache" "Composer cache"

# Clean JS dev tool caches and versions
safe_remove "$HOME/.bun/install/cache" "Bun cache"
safe_remove "$HOME/.bun/install/global" "Bun global installs"
safe_remove "$HOME/.pnpm" "pnpm store/cache"
safe_remove "$HOME/Library/Application Support/fnm/node-versions" "fnm Node.js versions"
safe_remove "$HOME/.local/state/fnm_multishells" "fnm multishells state"

# Clean temporary files
find /tmp -name ".com.apple.dt.CommandLineTools.*" -delete 2>/dev/null || true

# Clean user's temporary directory safely (only truly temp files)
if [[ -n "${TMPDIR:-}" && -d "$TMPDIR" ]]; then
    # Remove files older than 7 days owned by the current user
    find "$TMPDIR" -type f -mtime +7 -user "$(id -un)" -delete 2>/dev/null || true
    # Remove empty directories older than 7 days owned by the current user
    find "$TMPDIR" -type d -empty -mtime +7 -user "$(id -un)" -delete 2>/dev/null || true
fi
find "$HOME/.local/share/Trash" -type f -mtime +30 -delete 2>/dev/null || true

# Clean old log files
find "$HOME/Library/Logs" -name "*.log" -mtime +7 -delete 2>/dev/null || true

# # Clean downloads folder of common temporary files
# if [[ -d "$HOME/Downloads" ]]; then
#     echo "📥 Cleaning old downloads..."
#     find "$HOME/Downloads" -name "*.dmg" -mtime +30 -delete 2>/dev/null || true
#     find "$HOME/Downloads" -name "*.zip" -mtime +30 -delete 2>/dev/null || true
#     find "$HOME/Downloads" -name "*.tar.gz" -mtime +30 -delete 2>/dev/null || true
# fi

echo "✅ Cleanup complete! Cleaned $cleaned_count items."
echo "💡 Freed up disk space by removing temporary files and old caches."
