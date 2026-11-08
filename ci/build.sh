#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

collection=${1:?usage: ci/build.sh <collection>}

ansible-galaxy collection build --force "adams/$collection" --output-path dist/
