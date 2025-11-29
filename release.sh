#!/bin/bash
set -e

org=adams
collections=$(ls $PWD/$org)

NEXUS_REPO_URL=$1
NEXUS_USER=$2
NEXUS_PASS=$3
ENV=$4

if [[ $# -ne 4 ]]; then
    echo "Error: Invalid number of arguments."
    echo "Usage: $0 <NEXUS_REPO_URL> <NEXUS_USER> <NEXUS_PASS> <ENV>"
    exit 1
fi

for collection in $collections; do

    VERSION=$(grep '^version:' $org/$collection/galaxy.yml | awk '{print $2}')

    # Check if the tag already exists
    if git rev-parse "$collection-v$VERSION-$ENV" >/dev/null 2>&1; then
        echo "Tag $collection-v$VERSION-$ENV already exists. Skipping release."
        continue
    fi

    echo -e -n "\nBuilding collection binary for $collection version $VERSION-$ENV\n"

    ansible-galaxy collection build --force $org/$collection --output-path dist/

    TARFILE="dist/$org-$collection-$VERSION.tar.gz"

    echo -e -n "\nPulishing release for $collection version $VERSION-$ENV to github\n"

    git tag -a "$collection-v$VERSION-$ENV" -m "Release $collection version $VERSION for $ENV"
    git push origin "$collection-v$VERSION-$ENV"

    gh release create "$collection-v$VERSION-$ENV" dist/$org-$collection-$VERSION.tar.gz \
    --title "$org-$collection-v$VERSION-$ENV" \
    --notes "Automated release of $org-$collection version $VERSION for $ENV environment."

    echo -e -n "\nPublishing release for $collection version $VERSION-$ENV to Nexus artifactory\n"
    curl -u "$NEXUS_USER:$NEXUS_PASS" \
        --upload-file "$TARFILE" \
        "$NEXUS_REPO_URL/$ENV/$org-$collection-$VERSION-$ENV.tar.gz"

done

if [[ $? -eq 0 ]]
then
	echo -e -n '\nAutomated release completed... Removing dist folder\n'
	rm -rf $PWD/dist
fi
