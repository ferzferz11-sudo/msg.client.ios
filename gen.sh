#!/bin/bash
set -e

cd /root/msg.client.ios

echo "=== 1. Clean old xcodeproj ==="
rm -rf LavenderMessenger.xcodeproj

echo "=== 2. Generate xcodeproj ==="
xcodegen generate

echo "=== 3. Git commit and push ==="
git add -A
git diff --cached --stat
git commit -m "Regenerate xcodeproj"
git push origin main

echo "=== Done ==="
