#!/usr/bin/env bash
# Regenerates the distribution ZIPs in dist/ with arc42-generator (in Docker) and pushes them to a
# new branch, like "make release" does for arc42-template. Merging the pull request publishes them.
#
#   ./release.sh                       build, commit dist/ to a new branch, push it to 'origin'
#   ./release.sh --no-push             build and commit, but do not push
#   GENERATOR=/path/to/arc42-generator ./release.sh
#
# Needs: Docker with Compose v2, make, and a checkout of arc42-generator (default: ../arc42-generator).
# Uses your local git for the commit and push.
set -euo pipefail

GENERATOR="${GENERATOR:-../arc42-generator}"
REMOTE="${REMOTE:-origin}"
push=1
[ "${1:-}" = "--no-push" ] && push=0

cd "$(dirname "$0")"
here="$(pwd)"

[ -f "$GENERATOR/Makefile" ] || { echo "✗ No arc42-generator at $GENERATOR (set GENERATOR=...)" >&2; exit 1; }
command -v docker > /dev/null || { echo "✗ docker not found: start Docker Desktop" >&2; exit 1; }

if [ -n "$(git status --porcelain)" ]; then
  echo "✗ Working tree is not clean: commit or stash your changes first (only dist/ may change)." >&2
  exit 1
fi

# The ZIPs must correspond to the commit named in the branch and commit message.
sha="$(git rev-parse --short HEAD)"
gen="$(git -C "$GENERATOR" rev-parse --short HEAD)"

echo "==> Build with arc42-generator $gen from $here at $sha"
make -C "$GENERATOR" generate TEMPLATE="$here"
make -C "$GENERATOR" validate TEMPLATE="$here"

if [ -z "$(git status --porcelain -- dist)" ]; then
  echo "✓ dist/ is unchanged: nothing to release"
  exit 0
fi
if [ -n "$(git status --porcelain -- . ':!dist')" ]; then
  echo "✗ The build changed files outside dist/:" >&2
  git status --short -- . ':!dist' >&2
  exit 1
fi

branch="dist/$(date +%Y-%m-%d)-$sha"
git switch -q -c "$branch"
git add -A dist
git commit -q -m "Update the distribution ZIPs (generated from $sha with arc42-generator $gen)"
echo "✓ Committed dist/ on branch $branch"

if [ "$push" = 1 ]; then
  git push -q -u "$REMOTE" "$branch"
  echo "✓ Pushed $branch to $REMOTE. Open a pull request from it."
else
  echo "  Not pushed (--no-push). Push with: git push -u $REMOTE $branch"
fi
