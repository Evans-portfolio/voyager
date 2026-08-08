#!/bin/bash
# Registry lifecycle/retention for ACR Basic SKU, which has no native
# retention policy feature (Premium-only) - see README Cost Optimization.
#
# Runs on voyager via cron, not as an ACR Task. That's a deliberate change
# from how this was first built: the original version ran as an isolated
# ACR Task container with no path to either git or the clusters' live
# state, so it could only ever prune by tag count/age. That caused a real
# production outage (2026-08-08) - a run of infra-only commits (none of
# which touched sample-app source) still triggered new image builds on
# every push, and the keep-last-10 window pushed prod's actively-deployed
# tag out purely on count, with zero awareness that anything still
# referenced it. voyager already has git and kubectl access to both
# clusters for everything else in this project, so this moved here rather
# than trying to grant an isolated ACR Task container VNet/cluster access
# it has no other reason to need (and which Basic SKU may not even
# support).
#
# Protected-tag logic: before any deletion, read what tag every
# environment's values files currently declare (git, not live cluster
# state, so this works even if a cluster happens to be stopped at purge
# time) and never delete those, regardless of age or how many newer tags
# exist. Keep-last-10 still applies on top of that for everything else -
# this isn't a replacement for the recency window, just a correction for
# the one thing it was blind to.
set -uo pipefail

REPO_DIR="/root/server-sorcery-101"
REGISTRY="acrsorcerysorcery01"
LOGFILE="/var/log/acr-purge.log"
LOCKFILE="/tmp/acr-purge.lock"
LOCK_STALE_SECONDS=1200
KEEP_COUNT=10

SP_APPID="7aafd403-4839-4b0e-a899-4112bbe4438e"
SP_TENANT="7ba328b9-8f9f-4502-b9a0-65884b7f21bc"
SP_PASSWORD_FILE="$REPO_DIR/.ci-secrets/terraform-sp-password.txt"

log() {
  echo "$(date -u +'%Y-%m-%dT%H:%M:%SZ') $1" | tee -a "$LOGFILE"
}

OWN_LOCK="false"
cleanup() {
  if [ "$OWN_LOCK" = "true" ]; then
    rm -f "$LOCKFILE"
  fi
}
trap cleanup EXIT

if [ -e "$LOCKFILE" ]; then
  LOCK_AGE=$(( $(date +%s) - $(stat -c %Y "$LOCKFILE" 2>/dev/null || echo 0) ))
  if [ "$LOCK_AGE" -lt "$LOCK_STALE_SECONDS" ]; then
    log "SKIP: previous run still in progress (lockfile age ${LOCK_AGE}s)"
    exit 0
  fi
  log "WARN: stale lockfile (age ${LOCK_AGE}s) - previous run likely crashed, proceeding anyway"
fi
touch "$LOCKFILE"
OWN_LOCK="true"

log "=== acr-purge.sh starting ==="

if ! az login --service-principal --username "$SP_APPID" --password "@$SP_PASSWORD_FILE" --tenant "$SP_TENANT" -o none 2>>"$LOGFILE"; then
  log "FAIL: az login failed"
  exit 1
fi

cd "$REPO_DIR" || { log "FAIL: repo dir not found"; exit 1; }
GITLAB_TOKEN=$(cat "$REPO_DIR/.ci-secrets/gitlab_repo_token.txt" 2>>"$LOGFILE")
if [ -z "$GITLAB_TOKEN" ]; then
  log "FAIL: could not read gitlab repo token"
  exit 1
fi
# Read-only token (confirmed: fetch/clone work, push and API access are
# denied) - the right scope for a background job that only ever needs to
# read the current state of the values files, never write anything.
if ! git fetch "https://oauth2:${GITLAB_TOKEN}@gitlab.com/kipkiruivans/server-sorcery-101.git" main -q 2>>"$LOGFILE" || ! git checkout main -q 2>>"$LOGFILE" || ! git reset --hard FETCH_HEAD -q 2>>"$LOGFILE"; then
  log "FAIL: could not sync repo to latest main - refusing to purge with possibly-stale protected-tag data"
  exit 1
fi

PROTECTED_TAGS=$(grep -h 'tag:' \
  argocd/test/applications/values-backend.yaml \
  argocd/test/applications/values-frontend.yaml \
  argocd/prod/applications/values-backend.yaml \
  argocd/prod/applications/values-frontend.yaml \
  2>>"$LOGFILE" | sed -E 's/.*tag:[[:space:]]*"?([a-f0-9]+)"?.*/\1/' | sort -u)

if [ -z "$PROTECTED_TAGS" ]; then
  log "FAIL: could not determine any protected tags from values files - refusing to purge blind"
  exit 1
fi

log "Protected tags (currently declared in git for test+prod): $(echo "$PROTECTED_TAGS" | tr '\n' ' ')"

for repo in server-sorcery-101-backend server-sorcery-101-frontend; do
  log "=== $repo ==="
  ALL_TAGS=$(az acr repository show-tags --name "$REGISTRY" --repository "$repo" --orderby time_desc -o tsv)
  KEEP_RECENT=$(echo "$ALL_TAGS" | head -n "$KEEP_COUNT")

  echo "$ALL_TAGS" | while IFS= read -r tag; do
    [ -z "$tag" ] && continue
    if echo "$KEEP_RECENT" | grep -qx "$tag"; then
      continue
    fi
    if echo "$PROTECTED_TAGS" | grep -qx "$tag"; then
      log "SKIP (protected - currently deployed somewhere, outside keep-$KEEP_COUNT window): $repo:$tag"
      continue
    fi
    log "deleting $repo:$tag"
    az acr repository delete --name "$REGISTRY" --image "$repo:$tag" --yes 2>>"$LOGFILE"
  done
done

log "=== acr-purge.sh done ==="
