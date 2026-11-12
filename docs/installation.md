# Installation

Safari Tab Tamer declares AppleScript 2.7 and uses macOS's built-in Foundation framework and AppleScript tools. Safari must be installed. No browser extension, Python, Node.js, or package manager is required. Older macOS and Safari versions have not been verified; no broader version compatibility is claimed.

## Run from source

Download the repository's source archive or clone it:

```sh
git clone https://github.com/hashkode/safari-tab-tamer.git
cd safari-tab-tamer
osascript scripts/safari-tab-tamer.applescript --dry-run
```

`--dry-run` is also the default when no option is supplied. It inventories the URLs Safari exposes, asks which leading tabs to protect and which cleanup actions to preview, then reports the plan. It writes no backup and sends no close commands.

For cleanup, use:

```sh
osascript scripts/safari-tab-tamer.applescript --apply
```

Cleanup remains interactive. You must identify the protected prefix in every window and confirm the final plan. A verified backup is required before any close. Read [safety and recovery](safety.md) first.

## Open in Script Editor

1. Open `scripts/safari-tab-tamer.applescript` in **Script Editor**.
2. Review the source if desired.
3. Click **Run** to preview. An unmodified Script Editor run uses dry-run mode.

Use the command above with `--apply` when you want to close tabs without editing the source. You can also test a cleanup entirely in Script Editor using a temporary copy:

### Test cleanup in a Script Editor copy

1. Save a separate copy of `scripts/safari-tab-tamer.applescript` for the test.
2. Near the beginning of `on run argv`, change only the **first** `set applyMode to false` to `set applyMode to true`. Leave the other apply-mode statements and all safeguards unchanged.
3. Run that copy. The opening dialog must say **CLEANUP**. It still scans **all exposed Safari windows**, not just a disposable test window: enter protection counts carefully and select only the small cleanup you intend.
4. Review the plan and confirm only when ready. Manual protection, backup creation and verification, final confirmation, and session checks still apply.
5. Review the final planned, issued-command, and verified-closure counts and the backup location. Restore the first initialization to `set applyMode to false`, or discard the test copy, so later Script Editor runs return to dry-run mode.

This is an explicit local test override. The distributed source stays in dry-run mode by default.

### Progress and long waits

The current phase and counts appear at the bottom of the Script Editor window: scanning Safari, analyzing tabs, preparing the domain list, saving the backup, and verifying cleanup. Domain-menu counts use a single pass over eligible hostnames.

Safari itself may still take up to 300 seconds to answer each request. During that wait the progress text identifies the window or operation, but the bar cannot advance until Safari responds. Cleanup also verifies the whole exposed session before and after every close, so it takes longer than a preview. Use Stop to cancel; if a close command was already sent, follow the timeout/uncertain-outcome guidance in the safety document.

## Download and verify a release

The first release is v1.0.0, dated 2026-11-13. Its package uses these filenames; check [Releases](https://github.com/hashkode/safari-tab-tamer/releases) for published downloads:

- `safari-tab-tamer.scpt` — compiled AppleScript.
- `safari-tab-tamer-v1.0.0.zip` — release source archive.
- `SHA256SUMS` — checksums for both files.

Save all three files in the same folder. In Terminal, change to that folder and verify them before use:

```sh
shasum -a 256 -c SHA256SUMS
```

Both files should report `OK`. If either checksum fails, download the affected file again before running or extracting it.

## Use a compiled script

Open the verified `safari-tab-tamer.scpt` in Script Editor and click Run to preview the cleanup. You can also use it from Terminal:

```sh
osascript /path/to/safari-tab-tamer.scpt --dry-run
osascript /path/to/safari-tab-tamer.scpt --apply
```

To compile the source yourself, from the repository directory:

```sh
osacompile -o /tmp/safari-tab-tamer.scpt scripts/safari-tab-tamer.applescript
osascript /tmp/safari-tab-tamer.scpt --dry-run
```

These scripts are not signed or notarized applications. Do not disable macOS security features to run a download; use the readable source if your system blocks the compiled file.

## macOS permissions

On the first inventory, macOS may ask whether Terminal or Script Editor can control Safari. This is the Automation permission needed to read tab URLs and, only in apply mode, close selected tabs. Manage it in **System Settings → Privacy & Security → Automation**. Accessibility permission and Safari's “Allow JavaScript from Apple Events” setting are not required.

If permission is denied or Safari does not respond, the script should stop. Grant the intended host access and start a fresh run; do not assume a timed-out cleanup did nothing.

## Verify the installation

The following options do not contact Safari:

```sh
osascript scripts/safari-tab-tamer.applescript --version
osascript scripts/safari-tab-tamer.applescript --help
osascript scripts/safari-tab-tamer.applescript --self-test
sh tests/check.sh
```

Release preparation inspected Safari 27's scripting dictionary and passed local compilation and fixture checks. Manual validation included a user-confirmed end-to-end dry-run in Script Editor and a reported cleanup test using the temporary apply-mode copy: 20 planned tabs, 20 close commands issued, 20 verified closures, and a backup path reported. This was one user-reported run, not a full compatibility or failure-mode test. Use the [manual acceptance checks](safety.md#manual-acceptance-checks) with disposable tabs before cleaning a real session.

## Update or remove

Download a newer release or update your source checkout, review its changelog, then run the checks and a dry-run again. To uninstall, delete your checkout or downloaded script. Backups are retained separately at `~/Library/Application Support/Safari Tab Tamer/Backups/`; review and remove them yourself when no longer needed.
