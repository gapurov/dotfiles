#!/bin/bash

# Script to create a git worktree for a branch and copy configuration files
# Usage: ./worktree-branch.sh <branch_name> [parent_directory]
# Default parent directory is '../'
#
# Configuration files are determined by:
# 1. .configfiles (gitignore syntax) - if exists, copy files matching patterns + .configfiles itself
# 2. Default: .env* files and CLAUDE.md - if .configfiles doesn't exist

set -e

# Check if branch name is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <branch_name> [parent_directory]"
    echo "Example: $0 feature-branch"
    echo "Example: $0 feature-branch /path/to/parent"
    exit 1
fi

BRANCH_NAME="$1"
PARENT_DIR="${2:-../}"

# Ensure parent directory ends with /
if [[ ! "$PARENT_DIR" =~ /$ ]]; then
    PARENT_DIR="$PARENT_DIR/"
fi

# Create the worktree directory path
WORKTREE_PATH="${PARENT_DIR}${BRANCH_NAME}"

echo "Creating worktree for branch '$BRANCH_NAME' in '$WORKTREE_PATH'"

# Check if branch exists locally or remotely
if git show-ref --verify --quiet refs/heads/$BRANCH_NAME; then
    echo "Branch '$BRANCH_NAME' exists locally"
    git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"
elif git show-ref --verify --quiet refs/remotes/origin/$BRANCH_NAME; then
    echo "Branch '$BRANCH_NAME' exists remotely, creating local tracking branch"
    git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" "origin/$BRANCH_NAME"
else
    echo "Branch '$BRANCH_NAME' does not exist. Creating new branch from current HEAD"
    git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME"
fi

echo "Worktree created at: $WORKTREE_PATH"

# Copy configuration files
echo "Copying configuration files..."

# Function to copy files matching gitignore-style patterns
copy_files_from_configfiles() {
    local config_file="$1"
    local target_dir="$2"

    echo "Using .configfiles to determine files to copy..."

    # Copy .configfiles itself first
    cp "$config_file" "$target_dir/"
    echo "Copied $config_file"

    # Read .configfiles line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Remove leading/trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Skip negation patterns (lines starting with !)
        [[ "$line" =~ ^! ]] && continue

        # Use find to match patterns (similar to gitignore behavior)
        if [[ "$line" == *"/"* ]]; then
            # Pattern contains slash, treat as path
            if [[ -e "$line" ]]; then
                echo "Copying $line"
                cp -r "$line" "$target_dir/" 2>/dev/null || echo "Warning: Could not copy $line"
            fi
        else
            # Pattern doesn't contain slash, find matching files
            find . -maxdepth 1 -name "$line" -type f 2>/dev/null | while read -r file; do
                if [[ -f "$file" ]]; then
                    echo "Copying $file"
                    cp "$file" "$target_dir/"
                fi
            done
        fi
    done < "$config_file"
}

# Function to copy default files
copy_default_files() {
    local target_dir="$1"

    echo "Using default configuration (env files and CLAUDE.md)..."

    # Find all .env* files in the current directory
    for env_file in .env*; do
        if [ -f "$env_file" ]; then
            echo "Copying $env_file"
            cp "$env_file" "$target_dir/"
        fi
    done

    # Copy CLAUDE.md if it exists
    if [ -f "CLAUDE.md" ]; then
        echo "Copying CLAUDE.md"
        cp "CLAUDE.md" "$target_dir/"
    fi
}

# Check if .configfiles exists and use it, otherwise use defaults
if [ -f ".configfiles" ]; then
    copy_files_from_configfiles ".configfiles" "$WORKTREE_PATH"
else
    copy_default_files "$WORKTREE_PATH"
fi

echo "✅ Worktree setup complete!"
echo "📁 Location: $WORKTREE_PATH"
echo "🔧 To work in this worktree:"
echo "   cd $WORKTREE_PATH"
echo ""
echo "🧹 To remove the worktree later:"
echo "   git worktree remove $WORKTREE_PATH"
