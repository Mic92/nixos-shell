#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
cd "$SCRIPT_DIR/.."

version="${1:-}"
if [[ -z $version ]]; then
  echo "USAGE: $0 version" >&2
  exit 1
fi

if [[ "$(git symbolic-ref --short HEAD)" != "main" ]]; then
  echo "must be on main branch" >&2
  exit 1
fi

# ensure we are up-to-date
uncommitted_changes=$(git diff --compact-summary)
if [[ -n $uncommitted_changes ]]; then
  echo -e "There are uncommitted changes, exiting:\n${uncommitted_changes}" >&2
  exit 1
fi
git pull origin main
unpushed_commits=$(git log --format=oneline origin/main..main)
if [[ $unpushed_commits != "" ]]; then
  echo -e "\nThere are unpushed changes, exiting:\n$unpushed_commits" >&2
  exit 1
fi
# make sure tag does not exist
if git tag -l | grep -q "^${version}\$"; then
  echo "Tag ${version} already exists, exiting" >&2
  exit 1
fi

# main is protected by required status checks, so the bump has to go through a PR
branch="release-${version}"
git branch -D "$branch" 2>/dev/null || true
git checkout -b "$branch"
echo "$version" > version.txt
git add version.txt
git commit -m "bump version ${version}"
git push --force origin "$branch"
gh pr create \
  --base main \
  --head "$branch" \
  --title "Release ${version}" \
  --body "Release ${version} of nixos-shell"
gh pr merge --auto --rebase --delete-branch "$branch"
git checkout main

while [[ "$(gh pr view "$branch" --json state --jq .state)" != "MERGED" ]]; do
  echo "Waiting for PR to be merged..."
  sleep 10
done
git pull origin main
git branch -D "$branch" 2>/dev/null || true
gh release create "${version}" --draft --title "${version}" --generate-notes
