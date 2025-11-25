#!/usr/bin/env bash

# UniCore Linux Auto Git Sync Script
# Automatic git add, commit, and push with timestamp message

set -e

# Go to the script directory (project root)
cd "$(dirname "$0")"

echo "🔄 Adding all changes..."
git add .

echo "📝 Committing..."
git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')" || {
    echo "⚠️ Nothing to commit."
    exit 0
}

echo "⬆️ Pushing to GitHub..."
git push

echo "✅ Sync complete!"
