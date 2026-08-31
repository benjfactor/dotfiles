---
name: gcp-ci-watch
description: Get and watch GCP Cloud Build status for a GitHub PR. Reference skill — use when you need the authoritative build status for a PR. GitHub check statuses lag behind GCP for in-progress builds; always use GCP when status is PENDING or unknown.
---

# GCP Cloud Build — PR Status Reference

## Why GCP, not GitHub checks

`gh pr view` check statuses stay `PENDING` long after GCP finishes. GitHub is fine for determining an already-complete build (SUCCESS / FAILURE). For any build that is actively running or showing as pending, poll GCP directly for accurate status.

## Step 1: Get the Cloud Build ID

```bash
gh pr view <PR_NUMBER> --json statusCheckRollup \
  --jq '[.statusCheckRollup[] | select(.context == "ci/cloudbuild") | {status: (.state // .conclusion), url: (.targetUrl // .detailsUrl)}]'
```

The URL looks like:
```
https://console.cloud.google.com/cloud-build/builds;region=us-central1/<BUILD_ID>?project=642433220657
```

Extract the UUID between the last `/` and the `?`.

## Step 2: Get current build status

```bash
gcloud builds describe <BUILD_ID> --project=repcore-prod --region=us-central1 --format="value(status)"
```

Terminal statuses: `SUCCESS`, `FAILURE`, `CANCELLED`, `TIMEOUT`, `INTERNAL_ERROR`  
In-progress: `QUEUED`, `WORKING`

## Step 3: Monitor until terminal (Monitor tool, not a sleep loop)

```
while true; do
  status=$(gcloud builds describe <BUILD_ID> --project=repcore-prod --region=us-central1 --format="value(status)" 2>/dev/null || echo "ERROR")
  echo "$status"
  case "$status" in
    SUCCESS|FAILURE|CANCELLED|TIMEOUT|INTERNAL_ERROR|ERROR)
      break ;;
  esac
  sleep 60
done
```

Set `persistent: true` so it survives long builds. Each line the monitor emits is a notification.

## Step 4: On FAILURE — fetch the build log

```bash
gcloud builds log <BUILD_ID> --project=repcore-prod --region=us-central1 2>&1 | grep -B 5 -A 5 "ERROR\|Failed tasks"
```

## Quick reference

| Command | Purpose |
|---------|---------|
| `gcloud builds describe <ID> --project=repcore-prod --region=us-central1 --format="value(status)"` | Single status poll |
| `gcloud builds log <ID> --project=repcore-prod --region=us-central1` | Full build log |
| `gcloud builds list --project=repcore-prod --region=us-central1 --filter="trigger_id=a8be5a85-22ae-494c-94a8-3fed9262a5c8" --limit=5` | Recent branch builds |

**GCP project:** `repcore-prod`  
**Region:** `us-central1`  
**Branch build trigger ID:** `a8be5a85-22ae-494c-94a8-3fed9262a5c8`  
**E2E build trigger ID:** `9f799af6-1596-483c-bc29-11946cf51ed3`
