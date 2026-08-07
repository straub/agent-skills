---
name: jenkins-recon
description: Efficiently query a Jenkins organization/multibranch folder's REST API to investigate build failures across many jobs and branches — finding recent failures, checking console logs for a specific error, categorizing unknown/mixed failure causes, building a failure timeline, and tracing a shared-library commit to the PR that introduced it. Use when asked to check how many builds failed with some error, why builds are flaky, when a bug started, whether a fix held, or similar Jenkins-wide investigation.
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

## Finding the true first-failed stage via `wfapi/describe`

A multi-stage pipeline build's overall `result: FAILURE` doesn't tell you which
stage actually broke — one root failure (e.g. a test container dying) cascades
into every downstream stage also reporting FAILED, so the last failed stage in
the summary view is often a symptom, not the cause. Pipeline builds expose a
stage-level breakdown at:

```bash
curl -sS "<build-url>/wfapi/describe"
```

This returns each stage's `name`, `status`, and `startTimeMillis`. Sort by start
time and take the *first* stage with `status: FAILED` (a later `status: ABORTED`
usually just means Jenkins killed the rest of the pipeline after that earlier
failure) — that's the real root stage. Scope your log-reading to that stage
specifically rather than assuming the last FAILED stage mentioned is where the
problem started.

## Grep the failure, not a filename that also appears in success logs

A build log can mention the same filename/string in both a success message and an
error message. Matching on a substring like a bare filename will overcount — one
investigation went from ~40 true positives to over 1,000 by matching on a build
artifact's filename (e.g. `"some-manifest.json"`) instead of the actual failure
line (e.g. `"Error: ENOENT: no such file or directory, open '/path/to/some-manifest.json'"`).
Always grep the most specific fragment of the *actual error/exception text*, not
just an artifact name that could appear in unrelated log lines. Verify by manually
reading one matched log before trusting the count.

The same caution applies in reverse: a surprising **zero** matches from an
exact-string grep doesn't necessarily mean the error is absent — part of the
line can vary between occurrences (a resolved hostname, a container ID, a
dynamic port) even though it's the same underlying failure. If zero seems
wrong, loosen the pattern to a more stable substring, then manually verify
each hit before trusting that count either.

Use `scripts/grep-builds.sh` to check a list of build URLs for an exact string in
their console output (see script for usage — handles the parallelism gotchas below).

## Open-ended triage when you don't know the error text yet

The exact-string grep above assumes you already know what you're looking for.
When the task is "categorize the causes of these failures" rather than "did
error X recur," there's no string to grep for yet — you have to discover it:

1. **Sample, don't scan everything.** Pull a manageable set of failed builds
   (e.g. one recent failure per project, or the last N failures per job) rather
   than every failure across every branch — full coverage on unknown-shape data
   is expensive and mostly redundant once you've seen a few instances of each
   distinct cause.
2. **Pull a log window around the failure, not the whole log.** Use the failing
   stage from `wfapi/describe` above to scope which part of `consoleText` to
   read, or just check the tail — don't read an entire build log to find one
   error.
3. **Extract each build's failure signature and cluster.** Pull out the actual
   error line/exception from each sampled build and group builds by matching
   signature. A signature that recurs across *unrelated* jobs/repos is a real,
   systemic cause worth flagging first; one confined to a single job/build is
   more likely one-off flakiness.
4. **Filter to the stage(s) the question is actually about.** If you're asked
   to categorize failures in a specific stage (e.g. "why are the E2E tests
   flaky"), use the first-failed-stage from `wfapi/describe` to separate builds
   that failed *in* that stage from builds that never reached it because an
   earlier, unrelated stage failed first. A build that failed before the stage
   in scope isn't an instance of the thing you were asked about, even though
   its overall pipeline result is also FAILURE. Mention out-of-scope upstream
   failures as a brief aside if they're notably common — they may be worth a
   separate investigation — but don't fold their counts into the category you
   were asked to categorize.
5. **Only then scale up precisely.** Once a signature looks like the dominant
   cause, switch to the exact-string workflow above (`grep-builds.sh`) to get
   an accurate count across the full build set for that specific cause.
6. **Report what you sampled vs. skipped.** State the actual coverage (e.g.
   "one most-recent-failure per project, not full history") so a categorization
   from a sample isn't mistaken for an exhaustive count.

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
