#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

collection=${1:?usage: ci/syntax-check.sh <collection>}

cd "adams/$collection/roles"
for test in */tests/test.yml; do
    [ -f "$test" ] || continue
    role=${test%%/*}
    echo "syntax-check $collection/$role"
    ansible-playbook -i "$role/tests/inventory" "$test" --syntax-check
done
