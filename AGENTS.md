# agent-skills

Source of truth for the Agent Skills published from this repo. Each skill lives in
`skills/<name>/SKILL.md`.

## ⚠️ This repository is PUBLIC

Everything committed here is world-readable, including commit messages and PR titles and
bodies. Skills are frequently written up from real incidents at work — keep the technique,
drop the identifiers.

Never commit:

- Employer, client, or product names
- Internal hostnames, URLs, IP addresses, or account IDs
- Internal repo, job, folder, branch, or username values
- Ticket keys, PR/issue numbers from private repos, or internal doc links
- Verbatim log output or stack traces that carry any of the above

Write examples with placeholders — `https://<jenkins>/job/<org-folder>/...`, `<build-url>`,
`skills/<name>/SKILL.md`. Generic tooling identifiers are fine: `origin/HEAD`, `refs/heads/*`,
`.git/info/exclude` and similar carry no information about where you work.

**Sanitising a war story is not the same as weakening it.** Concrete detail is what makes a
skill worth reading, so keep the shape of it — "a count drifted downward for ~50 minutes while
the queue head never moved", "385 waiters turned out to be a sampling artifact". Those are
specific and instructive without naming anything. Drop the names, keep the numbers and the
failure mode. Dates are usually safe and help a reader judge staleness.

Before pushing, grep the diff *and* your commit message and PR body for anything from the list
above.

## Writing skills

- One skill per directory: `skills/<name>/SKILL.md`, with YAML frontmatter containing `name`
  and `description`. Supporting material goes in `scripts/`, `references/`, or `assets/`
  alongside it.
- **The `description` is the matching surface.** It decides whether the skill is loaded at all,
  so enumerate the vocabulary a user would actually reach for, not just the canonical framing.
  A skill about failures that never says "stuck", "hanging", or "slow" will not fire when it
  is most needed.
- **Keep the `description` YAML-safe.** It is a long unquoted scalar, so a bare `: ` inside it
  is read as a mapping key and breaks the entire frontmatter — `mapping values are not allowed
  here`. Use an em dash instead, or quote the whole value. Easy to hit precisely because the
  field is natural-language prose; CI catches it, but only after a push.
- Prefer what was learned the hard way — corrections to plausible-but-wrong assumptions, silent
  failure modes, tool gotchas. A skill that only restates the documentation adds nothing.
- Keep `SKILL.md` scannable. Section headings should be searchable statements of the problem,
  not labels.

## Editing an installed skill

Skills install as copies elsewhere on disk, so a skill edited through an agent's skills
directory is edited in the install, not in this repo, and can be overwritten by the next
update. Edit the checkout here, then reinstall. If an edit already happened in place, copy the
file back into this repo and review the diff before committing.
