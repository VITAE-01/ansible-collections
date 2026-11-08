#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
NAMESPACE=adams
errors=0
fail() { echo "ERROR: $*"; errors=1; }

for entry in $(ls -A adams); do
    dir="adams/$entry"
    if [ ! -d "$dir" ] || [ ! -f "$dir/galaxy.yml" ]; then
        fail "$dir is not a collection (missing galaxy.yml)"
        continue
    fi

    namespace=$(grep '^namespace:' "$dir/galaxy.yml" | awk '{print $2}')
    version=$(grep '^version:' "$dir/galaxy.yml" | awk '{print $2}')

    [[ "$namespace" == "adams" ]] \
        || fail "$dir/galaxy.yml: namespace '$namespace' must be 'adams'"
    [[ "$version" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]] \
        || fail "$dir/galaxy.yml: version '$version' must be a bare X.Y.Z semantic version"
done

exit "$errors"
