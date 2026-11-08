#!/bin/bash
# Release one collection: publish it to Nexus Galaxy, then record the release with the git tag
# <collection>-<VERSION> on the checked-out commit.
#
# Nexus is the source of truth for released version". The tag is written only after
# the version is confirmed in Nexus, so a tag never exists for a version that was not released.
#
#   Nexus has version | tag on origin | action
#   ------------------+---------------+-------------------------------------------------------
#   yes               | yes           | skip                                         (exit 10)
#   yes               | no            | add the missing tag (earlier tag push failed) (exit 11)
#   no                | no            | publish, verify, tag                          (exit 0)
#   no                | yes           | fail: tag without a release needs a human     (exit 1)
#   lookup error      | any           | fail, nothing changed                         (exit 1)
#
# Run it inside a per-collection lock so two builds never release the same collection at once.
# Tag lookups and pushes go over SSH to the checkout's `origin` repository (an https GitHub
# URL is rewritten to its SSH form). When GIT_SSH_KEY is set (the pipeline binds the job's
# SSH credential to it), git uses that key; otherwise the agent user's own SSH setup.
#
# Usage: ci/release.sh <collection>
# Needs: dist/adams-<collection>-<VERSION>.tar.gz (from ci/build.sh) and the
#        ANSIBLE_GALAXY_SERVER_NEXUS_* settings used by `ansible-galaxy --server nexus`.
set -euo pipefail
cd "$(dirname "$0")/.."

collection=${1:?usage: ci/release.sh <collection>}
: "${ANSIBLE_GALAXY_SERVER_NEXUS_URL:?NEXUS_GALAXY is not set on this agent}"

readonly SKIPPED=10 TAG_REPAIRED=11

version=$(grep '^version:' "adams/$collection/galaxy.yml" | awk '{print $2}')
tag="$collection-$version"
tarball="dist/adams-$collection-$version.tar.gz"
[ -f "$tarball" ] || { echo "ERROR: $tarball was not built"; exit 1; }

git_remote=$(git config --get remote.origin.url)
case "$git_remote" in
    https://github.com/*) git_remote="git@github.com:${git_remote#https://github.com/}" ;;
esac
if [ -n "${GIT_SSH_KEY:-}" ]; then
    export GIT_SSH_COMMAND="ssh -i \"$GIT_SSH_KEY\" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
fi

# Python interpreter that ansible-galaxy runs with (works for system, venv and pipx installs)
read -r -a galaxy_python <<< "$(sed -n '1s/^#!//p' "$(command -v ansible-galaxy)")"

# Exit code 0 = exists, 2 = not found, anything else = lookup failed
nexus_lookup() { "${galaxy_python[@]}" ci/nexus-version-exists.py adams "$collection" "$version"; }
tag_lookup()   { git ls-remote --exit-code --tags "$git_remote" "refs/tags/$tag" >/dev/null; }

lookup() {
    local rc=0
    "$2" || rc=$?
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
        echo "ERROR: could not check $1 for $tag (exit code $rc). Nothing was changed." >&2
        exit 1
    fi
    echo "$rc"
}

push_tag() {
    local head attempt remote
    head=$(git rev-parse HEAD)
    if ! git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
        git -c user.name="$(git config user.name || echo jenkins)" \
            -c user.email="$(git config user.email || echo "jenkins@$(hostname -f)")" \
            tag -a "$tag" -m "Release adams.$collection $version"
    fi
    for attempt in 1 2 3; do
        if git push "$git_remote" "refs/tags/$tag"; then
            return 0
        fi
        remote=$(git ls-remote "$git_remote" "refs/tags/$tag^{}" | awk '{print $1}')
        if [ "$remote" = "$head" ]; then
            return 0
        fi
        echo "WARNING: pushing $tag failed (attempt $attempt of 3)"
        [ "$attempt" -lt 3 ] && sleep $((attempt * 10))
    done
    return 1
}

in_nexus=$(lookup "Nexus" nexus_lookup)
on_origin=$(lookup "the git tag" tag_lookup)

case "$in_nexus/$on_origin" in
    0/0)
        echo "SKIP: adams.$collection $version is already released (tag $tag). Bump version in adams/$collection/galaxy.yml for a new release."
        exit "$SKIPPED"
        ;;
    0/2)
        echo "adams.$collection $version is in Nexus but tag $tag is missing (an earlier tag push failed). Adding the tag."
        push_tag || { echo "ERROR: could not push tag $tag. Re-run to retry the tag."; exit 1; }
        echo "TAGGED: $tag"
        exit "$TAG_REPAIRED"
        ;;
    2/0)
        echo "ERROR: tag $tag exists on origin but adams.$collection $version is not in Nexus."
        echo "Find out why the release is missing, then either republish it or delete the tag, and re-run."
        exit 1
        ;;
esac

echo "Publishing adams.$collection $version to Nexus Galaxy"
ansible-galaxy collection publish "$tarball" --server nexus

# Confirm Nexus lists the version before recording the release
for attempt in 1 2 3 4 5; do
    in_nexus=$(lookup "Nexus" nexus_lookup)
    [ "$in_nexus" -eq 0 ] && break
    if [ "$attempt" -eq 5 ]; then
        echo "ERROR: Nexus does not list adams.$collection $version. Skip tagging."
        exit 1
    fi
    sleep 5
done

push_tag || { echo "ERROR: adams.$collection $version is published, but tag $tag could not be pushed. The next run adds the tag."; exit 1; }
echo "RELEASED: adams.$collection $version (tag $tag)"
