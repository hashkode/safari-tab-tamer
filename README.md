# Safari Tab Tamer

Find Safari's busiest domains, preview a cleanup, and remove selected tabs or exact URL duplicates. A small native AppleScript utility using macOS Foundation, with no browser extension or third-party runtime.

**Starts in dry-run mode.** Closing tabs requires explicitly enabling apply mode, an explicit selection, manual pinned-tab protection, a verified URL backup, and confirmation.

## What it does

- Reads tab URLs in batches per window, with a 300-second AppleEvent timeout.
- Ranks hostnames by tab count, highest first; ties sort alphabetically.
- Builds domain-menu counts in one pass and shows phase/count progress in Script Editor.
- Lets you select multiple domains, including their subdomains, and/or deduplication.
- Keeps URLs distinct when their path, query, fragment, case, or trailing slash differs.
- Protects a manually specified number of leading tabs in each window.
- Saves a private, verified JSON URL inventory before cleanup.
- Rechecks the expected session before each close and stops on a change or error.

## Quick start

Requires macOS with AppleScript 2.7, Foundation, Safari, and the built-in AppleScript tools. No package installation is needed. Older macOS and Safari versions have not been verified.

```sh
git clone https://github.com/hashkode/safari-tab-tamer.git
cd safari-tab-tamer
osascript scripts/safari-tab-tamer.applescript
```

The default run only previews your selection. It does not close tabs or write a backup. macOS may ask permission for Terminal or Script Editor to control Safari.

When ready to clean up:

```sh
osascript scripts/safari-tab-tamer.applescript --apply
```

Follow the dialogs. Enter the number of leading tabs to preserve **for every window**. Enter `0` explicitly only if that window has no tabs you need to protect. Cancel if unsure.

| Option | Behavior |
| --- | --- |
| No option or `--dry-run` | Interactive inventory and preview; no Safari changes or backup |
| `--apply` | Interactive cleanup with backup and confirmation |
| `--self-test` | Local fixture checks; does not contact Safari |
| `--version` | Print the version; does not contact Safari |
| `--help` | Print usage; does not contact Safari |

See [installation](docs/installation.md) for Script Editor, a temporary cleanup test copy, and compiled-script instructions.

## Before closing tabs

**Pinned protection is manual.** Safari's scripting dictionary does not expose a pinned flag. The utility preserves the first N tabs you specify in each window; it cannot verify that you counted all pinned tabs. Protected copies are preferred when deduplicating.

**Backups recover URLs, not sessions.** Unsaved forms, scroll positions, browsing history, pin state, and Tab Group membership are not captured. Save work before applying cleanup and leave Safari alone while it runs.

**Scope is what Safari exposes.** Private-window URLs may be included. Inactive Tab Groups and other profile contexts are not reliably enumerated or identified. Close private windows before running if you do not want their URLs read or backed up.

Read [safety and recovery](docs/safety.md) before your first cleanup. Start with a few disposable tabs.

## Matching rules

Ranking lowercases hostnames and removes one leading `www.`. It does not merge every subdomain into a registrable domain. Selecting `example.com` matches that hostname and children such as `docs.example.com`, but never `notexample.com`. Selection labels show the eligible subdomain-inclusive count; overlapping selections close each tab at most once.

Deduplication uses **case-sensitive, exact full HTTP(S) URLs** across scanned windows. Protected tabs remain; otherwise the first encountered copy remains. No tracking parameters are removed, no query parameters are reordered, and no fragments are discarded. Tabs with other URL schemes or missing URLs are inventoried but never selected for cleanup.

## Backups

Each cleanup writes a new file before any close:

```text
~/Library/Application Support/Safari Tab Tamer/Backups/<UUID>/tabs.json
```

The backup includes the full scanned URL inventory and cleanup plan, including URLs you did not select. The backup directory is private (`0700`) and the JSON file is owner-readable/writable (`0600`). The write is atomic and read back for verification. Any backup failure aborts cleanup.

URLs can contain sensitive searches, document links, or authentication tokens. Keep backups local and out of repositories, support tickets, and shared folders. See [manual recovery](docs/safety.md#recovering-urls).

## Checks

```sh
sh tests/check.sh
```

Checks compile the AppleScript and exercise local fixtures without reading or changing your Safari tabs. Local compilation and fixtures passed during release preparation, and Safari 27's scripting dictionary was inspected.

Manual validation included a user-confirmed end-to-end dry-run in Script Editor, followed by a reported cleanup test with **20 planned tabs, 20 close commands issued, and 20 verified closures**, with a backup path reported. That run used a temporary Script Editor copy with apply mode enabled. This validates one reported run; it does not establish compatibility with every Safari version, Tab Group, profile, or failure condition. Use the [manual acceptance checks](docs/safety.md#manual-acceptance-checks) on disposable tabs before cleaning a real session.

## Releases and license

[Releases](https://github.com/hashkode/safari-tab-tamer/releases) contain release notes and, when available, a compiled `.scpt` download. Source remains readable and buildable with macOS's `osacompile`.

Version 1.0.0 is the first release, dated 2026-11-13. Based on the working Safari Tab Cleaner v2. See the [changelog](CHANGELOG.md). Licensed under [MIT](LICENSE).
