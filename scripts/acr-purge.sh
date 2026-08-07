#!/bin/sh
# Registry lifecycle/retention equivalent for ACR Basic SKU, which does not
# support native retention policies (Premium-only feature). Deployed as a
# scheduled ACR Task (daily, 0 3 * * *) with a system-assigned managed
# identity granted Reader (ARM, to resolve the registry) + AcrDelete (data
# plane) on the registry only. This file is the source of truth for what
# the task runs; the task itself carries a base64-encoded copy of this
# script directly in its --cmd (see README Cost Optimization section for
# the az acr task create invocation). Keeps the most recent 10 tags per
# repository, deletes the rest - simple keep-last-N rather than age-based,
# since this repo's tags are git short-SHAs with no "latest"/"stable"
# marker and both environments always pull an explicit tag.
set -eu

az login --identity -o none

for repo in server-sorcery-101-backend server-sorcery-101-frontend; do
  echo "=== $repo: tags beyond the most recent 10 ==="
  OLD_TAGS=$(az acr repository show-tags --name acrsorcerysorcery01 --repository "$repo" --orderby time_desc --query '[10:]' -o tsv)
  if [ -z "$OLD_TAGS" ]; then
    echo "nothing to purge"
    continue
  fi
  echo "$OLD_TAGS" | while IFS= read -r tag; do
    [ -z "$tag" ] && continue
    echo "deleting $repo:$tag"
    az acr repository delete --name acrsorcerysorcery01 --image "$repo:$tag" --yes
  done
done
