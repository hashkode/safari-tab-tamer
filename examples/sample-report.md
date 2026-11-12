# Example dry-run

Illustrative data only. This report does not contain a real browsing session and is not an exported file format.

Scanned: **10 tabs in 2 windows**. Manually protected: **1 leading tab in window 1; 0 in window 2**.

| Ranked hostname | Open tabs | Eligible tabs if selected, including subdomains |
| --- | ---: | ---: |
| `duckduckgo.com` | 4 | 4 |
| `example.com` | 3 | 3 |
| `docs.example.com` | 1 | 1 |

The remaining 2 tabs have non-HTTP(S) or missing URLs and are not cleanup candidates. One of the 3 `example.com` tabs is protected, so its selection affects 2 unprotected `example.com` tabs plus 1 `docs.example.com` tab.

Selected actions: `duckduckgo.com` and exact URL deduplication. Suppose the only redundant unprotected URL is already within the selected DuckDuckGo tabs:

- Proposed closes: **4**, counted once despite overlapping actions.
- Protected leading tab: **retained**.
- Other hostnames and non-HTTP(S) tabs: **retained**.
- Safari changes: **none**.
- Backup written: **none**; dry-run does not create a backup.

Run again with `--apply` to make a new inventory and plan. Cleanup still requires protection choices, confirmation, and a successful backup.
