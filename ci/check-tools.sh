#!/bin/bash
set -euo pipefail

missing=0
for tool in git ansible-galaxy ansible-playbook; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: $tool is not installed on this agent"
        missing=1
    fi
done
[ "$missing" -eq 0 ] || exit 1

ansible --version | head -1