#!/usr/bin/env bash
set -euo pipefail

echo "=== Step 1: Creating GitHub repo ==="
gh repo create techmart-platform --public --source=. --remote=origin --push

echo ""
echo "Done! Repo created and pushed."
