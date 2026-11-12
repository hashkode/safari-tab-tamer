# Safari Tab Tamer v1.0.0

First release — 2026-11-13.

Find Safari's busiest domains, preview bulk cleanup, and remove exact URL duplicates across exposed windows. Safari Tab Tamer is a native AppleScript utility using macOS Foundation, with no browser extension or third-party runtime.

## Features

- Default dry-run, explicit apply mode, and confirmation before cleanup.
- Batched URL retrieval, hostname ranking, subdomain matching, and one-pass domain-menu counts.
- Case-sensitive exact URL deduplication, preserving queries, fragments, tracking parameters, and trailing slashes.
- Manual leading-tab protection per window, with protected copies preferred during deduplication.
- Private verified JSON backups before any close.
- Native Script Editor phase/count progress and session checks before and after every close.
- Stop on a change, error, or timeout; the final report separates issued commands from verified closures.

## Downloads

Assets: `safari-tab-tamer.scpt`, `safari-tab-tamer-v1.0.0.zip`, and `SHA256SUMS`. Save all three in the same folder and verify both downloads before use:

```sh
shasum -a 256 -c SHA256SUMS
```

Both files should report `OK`. The `.scpt` opens in Script Editor; the ZIP contains the release source. See the [installation instructions](https://github.com/hashkode/safari-tab-tamer/blob/v1.0.0/docs/installation.md).

## Start with a preview

```sh
osascript scripts/safari-tab-tamer.applescript --dry-run
```

For cleanup, use `--apply` and follow the protection, selection, and confirmation dialogs. To test entirely in Script Editor, use a [temporary cleanup copy](https://github.com/hashkode/safari-tab-tamer/blob/v1.0.0/docs/installation.md#test-cleanup-in-a-script-editor-copy), then restore its dry-run default or discard it. The script scans all exposed windows, including when testing from Script Editor.

## Validation

Local compilation and fixture checks passed without reading or changing Safari tabs. Manual validation included a user-confirmed end-to-end dry-run in Script Editor and a reported cleanup test with **20 planned tabs, 20 close commands issued, and 20 verified closures**, with a backup path reported. That cleanup used a temporary Script Editor copy with apply mode enabled.

In a local fixture with 1,000 tabs across 50 domains, menu-count preparation took approximately 0.3 seconds. This measures local menu preparation only, excluding Safari scanning, dialogs, backup, and cleanup.

These results cover local fixtures and one user-reported live run, not every macOS/Safari version, Tab Group, profile, pinned-tab configuration, or failure condition.

## Safety limits

- Pinned status is not detected automatically. Enter the number of leading tabs to preserve in each window; local truncated URL hints help identify the window.
- Private-window URLs may be included. Inactive Tab Groups and other profiles are not reliably enumerated.
- Backups recover URLs, not unsaved forms or full Safari sessions.
- Safari offers no atomic session lock or stable tab IDs, so verification cannot eliminate every race.
- A timed-out close may still complete; inspect Safari before a fresh scan.

Read the [safety and recovery guide](https://github.com/hashkode/safari-tab-tamer/blob/v1.0.0/docs/safety.md) before closing real tabs. Licensed under MIT. See the [changelog](https://github.com/hashkode/safari-tab-tamer/blob/v1.0.0/CHANGELOG.md).
