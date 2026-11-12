# Safety and recovery

The distributed Safari Tab Tamer source starts in dry-run mode. Applying a cleanup can close pages with unsaved work. Save that work and begin with disposable tabs before using it on a browsing session you care about.

## What dry-run guarantees

A default run or `--dry-run` reads Safari's exposed tab URLs and displays the proposed cleanup. It does not close tabs or write a backup. Canceling a selection also leaves tabs unchanged.

`--apply` explicitly enables closing, but still requires interactive protection, selection, and confirmation. The [temporary Script Editor cleanup copy](installation.md#test-cleanup-in-a-script-editor-copy) is another explicit way to enable apply mode and retains those safeguards. Backup failure stops the run before any close command.

## Protecting pinned tabs

Safari's current scripting dictionary exposes no pinned-tab property. Protection is therefore **manual**, not automatic detection.

For each scanned window, enter how many leading tabs should be preserved. Safari places pinned tabs at the left side of the tab bar. Count all pinned tabs in that window, or enter a larger number to preserve additional tabs conservatively. The input starts blank; enter `0` explicitly only when no prefix needs protection. Cancel if you cannot identify the window or are unsure of the count.

Each prompt shows up to the first three leading URLs, truncated, as hints for identifying the window. These hints are displayed locally and can include sensitive URLs; they do not reveal whether a tab is pinned.

Protected tabs are excluded from domain cleanup and deduplication. When an exact URL appears in both protected and unprotected tabs, deduplication keeps the protected copies. It does not remove extra protected copies.

The utility cannot verify your count or detect a tab pinned after the scan. Do not change pins, switch Tab Groups, reorder tabs, navigate, open or close windows, or otherwise use Safari while cleanup runs.

Apple documents [pinned-tab placement](https://support.apple.com/en-lamr/guide/safari/ibrw0495694f/mac).

## Scope and privacy

The inventory covers the windows and tabs Safari exposes to AppleScript at scan time. It is not a complete inventory of every saved Safari context.

- Private-window URLs may be exposed and included; private windows cannot be reliably identified or excluded by this interface.
- Inactive Tab Groups and other profiles are not reliably enumerated or identified.
- Non-HTTP(S) and missing URLs are inventoried but excluded from cleanup.
- URL strings that Foundation cannot parse as HTTP(S) with a hostname are also excluded from cleanup, while remaining in the inventory.
- The script does not read page contents, send URLs to a service, or require JavaScript or Accessibility access.

Close private windows before running if you do not want their URLs read or backed up. If Tab Groups or profiles are important to your workflow, first verify Safari's exposed scope using a small dry-run.

## Exactly what deduplication means

Only identical, case-sensitive full HTTP(S) URLs count as duplicates. These pairs remain separate:

| URL A | URL B | Reason |
| --- | --- | --- |
| `https://example.com/A` | `https://example.com/a` | Path case |
| `https://example.com/?q=A` | `https://example.com/?q=a` | Query case |
| `https://example.com/page` | `https://example.com/page/` | Trailing slash |
| `https://example.com/#one` | `https://example.com/#two` | Fragment |
| `https://example.com/?a=1&b=2` | `https://example.com/?b=2&a=1` | Query order |
| `https://example.com/` | `https://example.com/?utm_source=x` | Tracking parameter |

Protected copies take precedence. Otherwise, the first copy encountered in the scan remains. Exact URL equality does not imply identical page state: two tabs at the same URL can contain different forms, navigation history, or application state. Save those before deduplicating.

The script uses explicit exact comparisons because [AppleScript's usual text comparisons](https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/reference/ASLR_operators.html) can ignore case.

## Backup requirements

Before closing anything, apply mode writes a JSON backup of the full scanned URL inventory and cleanup plan to:

```text
~/Library/Application Support/Safari Tab Tamer/Backups/<UUID>/tabs.json
```

A unique directory avoids overwriting earlier runs. The script requires private directory permissions (`0700`), file permissions (`0600`), an atomic write, and successful readback verification. Write, permission, or verification errors abort the cleanup.

The backup contains URLs you did not select, possibly including private-window URLs. URLs can reveal searches, private document names, authentication tokens, and account details. Local permissions do not prevent access by administrators, backup software, or a cloud service syncing that location. Do not publish backups, paste them into an issue, or place them in a Git repository. Review and delete old backups manually when no longer needed.

### Recovering URLs

The final dialog gives the backup path. To recover pages:

1. Open the JSON backup in a local text editor.
2. Find the URL entries for the tabs you want to recover.
3. Copy each URL into Safari's address bar, opening a new tab as needed.

Read JSON escape sequences as decoded text; do not paste a surrounding JSON quote or backslash escape into the address bar. Open only URLs you recognize. There is no automatic bulk restore in v1.0.

This is URL recovery, not a session restore. The backup does not capture unsaved forms, page content, cookies, scroll positions, per-tab history, pin state, Tab Group membership, or profile context. A URL may have expired or require authentication.

## Changes, errors, and timeouts

Cleanup processes planned tabs in reverse index order. Before every close, it checks the full expected exposed session, then checks the exact target URL. After each close, it reads the session again to verify the expected remaining URLs before counting that closure as confirmed. It stops at the first mismatch or error and never retries automatically.

The final report separates **verified closures** from **close commands issued**. If those counts differ, the last command has an uncertain outcome: a tab may have closed without passing the follow-up check, or an outstanding close may still complete. Inspect Safari and the backup before a fresh scan.

These checks reduce the chance of targeting a shifted tab, but Safari offers no atomic session lock or stable tab IDs through its AppleScript tab interface. A change between verification and close remains possible. Reordered tabs with identical URLs can be indistinguishable even when their page state differs.

Every Safari AppleEvent has a 300-second timeout. A timeout does **not** cancel the operation already sent to Safari, as explained in [Apple's timeout reference](https://developer.apple.com/library/archive/documentation/AppleScript/Conceptual/AppleScriptLangGuide/reference/ASLR_control_statements.html). Some tabs may already have closed, and an outstanding operation may still complete. Inspect Safari and the backup, wait for Safari to settle, and start a fresh scan. Never reuse a previous plan or assume that an interrupted cleanup changed nothing.

## Validation scope

Manual validation included a user-confirmed end-to-end dry-run in Script Editor, followed by a reported cleanup test using a temporary copy with the first apply-mode initialization enabled: **20 planned tabs, 20 close commands issued, and 20 verified closures**, with a backup path reported. No real URLs, backup identifiers, or personal filesystem paths are included in this validation record.

This is one user-reported successful run. It does not validate every macOS or Safari version, pinned-tab configuration, Tab Group, profile, private window, race condition, or backup failure. Automated checks remain separate and do not access Safari.

## Manual acceptance checks

Automated checks compile the source and run local fixtures without contacting Safari. They do not validate live tab deletion, Safari permissions, or every Safari version. Before first use, test with disposable tabs and no unsaved work:

| Check | Expected result |
| --- | --- |
| Run without options; select a domain and duplicates | Preview only; no tab closes and no backup is written |
| Cancel protection, selection, or final confirmation | No close commands are sent |
| Pin a disposable leading tab; enter the correct prefix count | Protected tab remains, including when its domain is selected |
| Open protected and unprotected copies of the same URL | Deduplication preserves protected copies |
| Open URLs differing only in case, fragments, query order, or trailing slash | They are not treated as exact duplicates |
| Select a parent hostname and its child hostname together | Affected tabs are counted and closed only once; unrelated lookalike domains remain |
| Apply a small cleanup | A readable private JSON backup exists before cleanup; reported results match Safari |
| Make the backup location unwritable in a disposable test environment | Backup fails and no tabs close |
| Change a tab or window after planning | Cleanup stops when revalidation detects the change; inspect any earlier closes |
| Try a small Tab Group/profile session | Confirm actual exposed scope; do not infer inactive groups are covered |
| Use a disposable private window only if comfortable with local URL storage | Treat its URLs as potentially included in the inventory and backup |

Do not deliberately trigger timeouts or filesystem failures against an important browsing session.
