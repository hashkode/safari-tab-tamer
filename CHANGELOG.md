# Changelog

## 1.0.0 — 2026-11-13

First release of Safari Tab Tamer, based on the working Safari Tab Cleaner v2.

### Features

- Default interactive dry-run and explicit `--apply` cleanup mode.
- Script Editor and command-line launches, with native progress showing phases and counts.
- Batched URL retrieval per window with a 300-second AppleEvent timeout.
- Hostname ranking by tab count, deterministic alphabetical ties, and one-pass domain-menu counts.
- Multi-domain cleanup with subdomain matching, protected-tab exclusions, and overlapping selections counted once.
- Case-sensitive exact HTTP(S) URL deduplication across scanned windows, preserving query parameters, fragments, and trailing-slash differences.
- Per-window manual protection for leading tabs, including pinned tabs; protected copies take priority during deduplication.
- Private JSON backups with unique names, atomic writes, permissions checks, and readback verification before cleanup.
- Explicit confirmation, reverse-index closing, and whole-session verification before and after each close.
- Stop on the first change, error, or timeout, with separate issued-command and verified-closure counts.
- Installation, safety, manual URL recovery, and MIT license documentation; source and compiled-script release packaging with checksums.

### Validation

- Local compilation and fixture checks cover launch arguments, URL comparisons, domain ranking and matching, protected keepers, plan overlap, stale scans, and private JSON backups without contacting Safari.
- User-confirmed end-to-end Script Editor dry-run, followed by a reported cleanup test with 20 planned tabs, 20 commands issued, 20 verified closures, and a backup path reported.
- Local menu-count fixture: approximately 0.3 seconds for 1,000 tabs across 50 domains. This measures menu preparation only, excluding Safari scanning, backup, and cleanup.

### Known limitations

- Pinned status is not automatically detected; leading-tab protection depends on the counts entered for each window.
- Private-window status, inactive Tab Groups, profiles, and stable tab IDs are not exposed sufficiently for reliable automatic handling.
- Backups recover URLs, not unsaved work or full browser sessions.
- Safari changes cannot be locked atomically; identical-URL tabs remain indistinguishable, and a timed-out close may still complete.
- The reported live test covers one run. Automated checks do not contact Safari, and broad version, Tab Group, profile, and failure-mode compatibility is unverified.
