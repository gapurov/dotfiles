#!/usr/bin/env bash

echo ""
echo "AutoPush Obsidian"

cd /Users/vgapurov/Documents/Obsidian/gapurov-obsidian

echo "`date`: RUNNING: git add ."
/opt/homebrew/bin/git add .

echo ""

echo "`date`: RUNNING: commit -m 'Auto Update'"
/opt/homebrew/bin/git commit -m 'Auto Update'.

echo ""

echo "`date`: RUNNING: git pull"
/opt/homebrew/bin/git pull origin main
echo "`date`: FINISHED: git pull"

echo ""

echo "`date`: RUNNING: git pull"
/opt/homebrew/bin/git push origin main

echo ""

echo "All done! Enjoy a cold one! 🍺 "
