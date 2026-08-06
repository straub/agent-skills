---
name: jenkins-recon
description: Efficiently query a Jenkins organization/multibranch folder's REST API to investigate build failures across many jobs and branches — finding recent failures, checking console logs for a specific error, building a failure timeline, and tracing a shared-library commit to the PR that introduced it. Use when asked to check how many builds failed with some error, when a bug started, whether a fix held, or similar Jenkins-wide investigation.
---

# Jenkins Recon

Techniques for investigating build failures across a Jenkins organization folder
(multibranch projects, many jobs × many branches) without drowning in requests or
false positives.

## Use curl, not WebFetch, for the Jenkins API

`WebFetch` pipes content through a summarizing model — it will silently truncate a
large JSON response (e.g. hundreds of jobs) down to a couple of entries with no
warning. Hit the JSON API directly with `curl` and parse it yourself
(`python3 -c 'import json...'` or `jq`). URL-encode the `tree` param's brackets
(`%5B` `%5D`) since raw `[`/`]` breaks some shells/curl invocations:

```bash
curl -sS "https://<jenkins>/job/<org-folder>/api/json?tree=jobs%5Bname%5D"
```

## `tree=` shapes for multibranch org folders

- All branch jobs' current status:
  `jobs[name,jobs[name,lastBuild[number,result,timestamp,url]]]`
- Last N builds per branch (recent history without walking every job):
  `jobs[name,jobs[name,builds[number,result,timestamp,url]{0,N}]]`
- Scope to one job's branches directly (skip the org-folder nesting) by hitting
  `.../job/<org-folder>/job/<project>/api/json?tree=...` instead.

## Scope ladder — don't ask for everything at once

A single `builds{0,50}` query across every job in a large org folder can time out
when the folder contains many jobs. Narrow before you widen:

1. **Sweep**: org-wide `lastBuild`-only query (cheap, one request) to see current
   state everywhere.
2. **Filter**: in Python/jq, keep only what's in the time window you care about.
3. **Drill down**: only *then* fetch per-branch `builds{0,N}` history, and only for
   the subset of projects/branches that survived step 2.

This also applies to console-log checks: don't fetch `consoleText` for every build
you have URLs for if a cheaper filter (result, timestamp) can shrink the list first.

## Grep the failure, not a filename that also appears in success logs

A build log can mention the same filename/string in both a success message and an
error message. Matching on a substring like a bare filename will overcount — one
investigation went from ~40 true positives to over 1,000 by matching on a build
artifact's filename (e.g. `"some-manifest.json"`) instead of the actual failure
line (e.g. `"Error: ENOENT: no such file or directory, open '/path/to/some-manifest.json'"`).
Always grep the most specific fragment of the *actual error/exception text*, not
just an artifact name that could appear in unrelated log lines. Verify by manually
reading one matched log before trusting the count.

Use `scripts/grep-builds.sh` to check a list of build URLs for an exact string in
their console output (see script for usage — handles the parallelism gotchas below).

## Tracing a shared Jenkins library commit to its PR

When builds check out a shared library (`Loading library <name>@...` /
`Checking out Revision <sha>` in the console log), you can go from "these builds all
picked up revision X" to a real causal story:

1. Grab the shared-library revision from console logs of a last-good build and a
   first-bad build for the same job — if they differ, that's your suspect commit range.
2. Find the PR that introduced it:
   `gh api repos/<org>/<lib-repo>/commits/<sha>/pulls`
   → gives PR number, title, diff, and `merged_at` timestamp.
3. Diff the two revisions directly:
   `gh api repos/<org>/<lib-repo>/compare/<old-sha>...<new-sha> --jq '.files[].patch'`
4. Compare `merged_at` against the first-failure timestamp from the Jenkins data —
   minutes-level alignment across multiple independently-triggered jobs is strong
   causal evidence, not coincidence.
5. If the library step just wraps scripts from another package (e.g. a
   `node_modules/@org/pkg/bin/*.sh` shim), fetch that package's repo too
   (`gh api repos/<org>/<pkg-repo>/contents/<path>`) — the real logic, and the real
   fix, is often one level deeper than the shared-library `vars/*.groovy` file.

## Parallelizing console-log checks (BSD xargs gotchas)

On macOS, `xargs` is BSD xargs, not GNU:

- No `-a file` flag — pipe input instead: `cat urls.txt | xargs -P 8 -I{} ...`
- Inline `bash -c '...'` with several layers of quoting embedded in `-I{}` can fail
  with `xargs: command line cannot be assembled, too long` even for a short,
  reasonable-looking command. Write a small wrapper script and call that from
  `-I{}` instead of inlining the logic — see `scripts/grep-builds.sh`.

## Before/after verification when checking if a fix held

Don't stop at "0 matches" — that can mean "fixed" or "I didn't check the right
builds." Re-run the *same* precise grep against builds from after the fix landed,
across enough volume to be meaningful (a handful of builds in the first hour is
weak evidence; a day's worth of real traffic including some unrelated failures is
strong evidence). For any build that still fails post-fix, read its console log
manually to confirm the failure is unrelated rather than assuming a clean bill of
health.
