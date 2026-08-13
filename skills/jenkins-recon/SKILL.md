---
name: jenkins-recon
description: Investigate the state of a Jenkins instance through its REST API, console logs, thread dumps, and container logs — build failures, hangs and stalls, queue backlogs, lock contention, restarts and deploys, capacity, and verifying whether a change or fix actually took effect. Use for any Jenkins-wide reconnaissance question: how many builds hit some error, why builds are stuck or slow, when something started, what is blocking what, whether a config change applied, or whether a fix held.
---

# Jenkins Recon

Techniques for investigating build failures across a Jenkins organization folder
(multibranch projects, many jobs × many branches) without drowning in requests or
false positives.

## Use curl, not WebFetch, for the Jenkins API

`WebFetch` pipes content through a summarizing model — it will silently truncate a
large JSON response (e.g. hundreds of jobs) down to a couple of entries with no
warning. Hit the JSON API directly with `curl` and parse it yourself
(`python3 -c 'import json...'` or `jq`). Pass `-g` (`--globoff`). The `[`/`]` in a `tree=` param are not a shell problem —
**curl** treats them as its own URL-globbing syntax and silently returns an empty
body with **exit code 0**, no error message. Silent-empty is the signature; if a
`tree=` query returns nothing, suspect this before suspecting auth or the query.

```bash
curl -sg -n "https://<jenkins>/job/<org-folder>/api/json?tree=jobs[name]"
```

`-g` keeps the query readable; percent-encoding as `%5B`/`%5D` also works if you
prefer. `-n` uses `~/.netrc` for auth.

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

## Don't trust the named scope when shared infrastructure is involved

If the thing being investigated could stem from infrastructure shared across org
folders — a global library cache, a lock, a shared executor pool — the org
folder(s) named in the request are not necessarily the whole blast radius. On
2026-08-12 a lock holder lived in a folder nobody had mentioned, with waiters in
two more; the request named only two of the five that mattered. Sweep every org
folder on the instance (`curl .../api/json?tree=jobs[name]` at the root lists
them) or explicitly confirm scope before concluding a root cause is isolated to
the folders named up front.

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

Two more variants of "the pattern quietly disagrees with reality", both of which
cost real time on a 2026-08-12 investigation:

- **Ref-name variants.** Exact-matching `Could not find origin/HEAD` missed every
  `Could not find refs/remotes/origin/HEAD`, undercounting the bucket for several
  cycles and masking the one build that actually held the lock. When a version or
  ref string can be spelled more than one way, match the stable fragment.
- **A missing line is itself a state.** Classifying on the *presence* of a line
  assumes every healthy build prints it. When a shared library is served from
  cache it never prints `Attempting to resolve`, so a classifier keyed on that
  bucketed 326 perfectly healthy builds as "unknown". Before trusting a bucket,
  ask what a *successful* build omits.

Use `scripts/grep-builds.sh` to check a list of build URLs for an exact string in
their console output (see script for usage — handles the parallelism gotchas below).

## Thread dumps when builds are stuck rather than failing

A stalled build often shows nothing useful in its own console — the last line is
whatever printed before it blocked, and the REST API just reports `building: true`.
The controller-wide thread dump is what identifies the blocker.

```bash
curl -sg -n "https://<jenkins>/threadDump" -o /tmp/td.txt
grep -oE 'owned by "[^"]*" Id=[0-9]+' /tmp/td.txt | sort | uniq -c | sort -rn | head
```

Ranking by waiter count immediately names the contended locks and who holds them.
Then pull the owner's own stack (search its `Id=` where it is *not* preceded by
`owned by`) to see what the holder is actually doing — that distinguishes "holder
is doing slow legitimate work" from "holder is itself blocked on something else".

Watch for stacked locks: on 2026-08-12 a build held a fair `ReentrantReadWriteLock`
while itself parked on a JVM-global `ReentrantLock` one layer down, so ~850 threads
queued behind two `git fetch` subprocesses. The console showed only the first
symptom; only the dump showed the chain.

Note the last console line pins the blocking call precisely — if a known code path
prints X then immediately takes a lock, a log ending at X *is* the lock wait.

## When the endpoints you need return 403

A token can read `/api/json` fine and still be refused the diagnostic endpoints —
`/threadDump`, `/configuration-as-code/export`, and `/manage/configure` all 403 for
a non-admin token. `/manage/configure` returns a short error page rather than an
HTTP error, so check the byte count, not just the status.

When config is unreadable, infer it from behaviour instead of giving up: pick an
observable whose rate or timing differs between the candidate values and measure
that. Prefer this even when you *can* read the config — it tests what is in effect,
not what is displayed.

## Inferring a blocked config value from event frequency

The general form of the pointer above: if a config value gates how *often* some
observable event fires, count that event over a time window and compare the rate
against what each candidate value would predict. A refresh/TTL-style setting is
the clean case — a short interval produces a rate roughly an order of magnitude
higher than a long one, so a handful of occurrences in 30 minutes is enough to
tell 5-minute from 90-minute apart without ever reading the value.

## `lastBuild`-only sampling hides stuck builds

Sweeping `jobs[name,jobs[name,lastBuild[...]]]` is cheap and usually right, but a
stuck build silently leaves your sample the moment a newer build starts on the same
branch. A falling "stuck" count can therefore mean supersession, not recovery.

Cross-check against whether the *queue head* moves: if the same build has been
oldest for several consecutive checks, nothing is draining regardless of what the
count says. On 2026-08-12 a count drifted downward for ~50 minutes while the head
never moved once.

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
- macOS ships bash 3.2: no associative arrays (`declare -A` fails with
  `invalid option`). A wrapper script avoids this too.
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

## Running the same check on a recurring cadence

When a fix or an incident needs watching over many cycles rather than one-shot
verification, match the check interval to how fast the signal is actually
changing, not to a fixed default — tight (10–15s) right after a risky event like
a deploy or restart where the interesting window is the first couple of minutes,
5 minutes for ordinary steady-state watching, 10+ minutes or stopping entirely
once several consecutive cycles have shown nothing. Widen or narrow explicitly
rather than leaving one cadence running out of inertia. (A 5-minute default also
happens to sit comfortably inside typical prompt-cache TTLs, so it's a reasonable
starting point on cost grounds alone — but that's a token-cost argument, not a
signal-value one; let the actual rate of change move you off it in either
direction.)

If you're reporting an ETA (e.g. "backlog clears in ~N minutes") derived from a
trend across your own prior checks, say so explicitly and state it as a range
when the trend is noisy rather than a single confident number — a metric that
oscillates rather than monotonically drains will make a point estimate look more
precise than the data supports.

Engaging a maintenance/quiet-down mode to stop new arrivals is a legitimate
diagnostic move here, not just an operational safety step — freezing arrivals is
often the only way to tell whether something is truly draining versus being
masked by churn (new items arriving as fast as old ones resolve).

When deciding whether to escalate mid-watch, don't fire on one raw number alone.
A single metric crossing a threshold is often a sampling artifact of whatever
you're polling, not a real state — prefer requiring two or more correlated
signals together (e.g. "the specific thing you'd blame is actually present" AND
"the downstream count is elevated"), and check whether it's the *same* items
persisting across consecutive samples rather than just whether a count stays
high. A count that holds steady while its members completely turn over isn't
persistence; a count that swings while one specific item never moves is.
