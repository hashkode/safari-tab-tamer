use AppleScript version "2.7"
use framework "Foundation"
use scripting additions

-- Safari Tab Tamer 1.0.0. Derived from the working Safari Tab Cleaner v2.
-- MIT License. Copyright (c) 2026 Tobias (hashkode).
-- No Safari commands are sent by --help, --version, or --self-test.

on run argv
    -- Script Editor can pass its application object rather than a CLI argument list.
    set argv to my launchArguments(argv)
    set applyMode to false
    if (count of argv) > 1 then error "Use one option; see --help." number 64
    if (count of argv) = 1 then
        set optionName to item 1 of argv
        if my exactText(optionName, "--version") then return "1.0.0"
        if my exactText(optionName, "--help") then return "Safari Tab Tamer 1.0.0" & linefeed & "Usage: osascript safari-tab-tamer.applescript [--dry-run | --apply | --self-test | --version | --help]" & linefeed & "Default: interactive dry-run. --apply still requires selection, manual pinned-tab protection, a verified backup, and confirmation."
        if my exactText(optionName, "--self-test") then return my selfTest()
        if my exactText(optionName, "--apply") then
            set applyMode to true
        else if not my exactText(optionName, "--dry-run") then
            error "Unknown option; see --help." number 64
        end if
    end if
    try
        set resultText to my interactiveRun(applyMode)
        my clearProgress()
        return resultText
    on error errMsg number errNum
        my clearProgress()
        if errNum = -128 then return "Cancelled."
        display alert "Safari Tab Tamer stopped" message ("Error " & errNum & ": " & errMsg & return & return & "Do not retry a cleanup after a timeout until Safari has settled. Start a fresh scan.")
        return "Stopped. Start a fresh scan before trying again."
    end try
end run

on launchArguments(rawArguments)
    -- Do not coerce Cocoa collections or strings into executable CLI options.
    -- Even asking the GUI host object's class can raise -1728, so guard that too.
    try
        if class of rawArguments is list then return rawArguments
    end try
    return {}
end launchArguments

on reportProgress(phaseText, detailText, totalSteps, completedSteps)
    set progress total steps to totalSteps
    set progress completed steps to completedSteps
    set progress description to phaseText
    set progress additional description to detailText
end reportProgress

on clearProgress()
    -- Clearing a cancelled progress display must not hide the original error.
    try
        set progress total steps to 0
        set progress completed steps to 0
        set progress description to ""
        set progress additional description to ""
    end try
end clearProgress

on interactiveRun(applyMode)
    if application "Safari" is not running then
        display dialog "Safari is not running. Open Safari first." buttons {"OK"} default button "OK"
        return "Safari is not running."
    end if
    set modeText to "DRY RUN"
    if applyMode then set modeText to "CLEANUP"
    display dialog (modeText & return & return & "Scans the tabs Safari exposes in every open window, which may include private browsing. Inactive Tab Groups may be missing." & return & return & "Safari cannot report pinned status. Next, enter the number of leading tabs to protect in each window. Cancel if unsure." & return & return & "URL backups cannot recover unsaved forms or full sessions.") with title "Safari Tab Tamer" buttons {"Cancel", "Scan"} default button "Cancel" cancel button "Cancel"
    set snapshot to my readSnapshotWithProgress(true)
    if (count of snapshot) = 0 then return "No Safari windows found."
    set totalTabs to 0
    repeat with winRef in snapshot
        set winInfo to contents of winRef
        set tabTotal to count of tabURLs of winInfo
        set totalTabs to totalTabs + tabTotal
        if tabTotal > 0 then
            set protectedCount of winRef to my askProtectedCount(windowID of winInfo, tabTotal, my windowHint(tabURLs of winInfo))
        end if
    end repeat
    if totalTabs = 0 then return "No Safari tabs found."
    set allTabs to my inventoryWithProgress(snapshot, true)
    my reportProgress("Ranking domains", "Counting " & totalTabs & " scanned tabs", totalTabs, 0)
    set ranked to my rankDomains(allTabs)
    set affectedCounts to my affectedDomainCounts(allTabs, true)
    my reportProgress("Preparing domain list", "Building " & (count of ranked) & " menu entries", count of ranked, 0)
    set optionsList to {}
    set duplicateCount to 0
    repeat with t in allTabs
        if isDuplicate of t then set duplicateCount to duplicateCount + 1
    end repeat
    set dupeOption to "Deduplicate exact URLs | " & duplicateCount & " eligible redundant tabs"
    if duplicateCount > 0 then set end of optionsList to dupeOption
    repeat with row in ranked
        set h to hostName of row
        set affected to affectedCounts's objectForKey:h
        if affected is missing value then set affected to 0
        set affected to affected as integer
        set end of optionsList to (tabCount of row as text) & " tabs | " & h & " | closes " & affected & " incl. subdomains"
    end repeat
    my clearProgress()
    if (count of optionsList) = 0 then
        display dialog "No HTTP(S) tabs available for cleanup." buttons {"OK"} default button "OK"
        return "No HTTP(S) tabs."
    end if
    set chosen to choose from list optionsList with title ("Safari Tab Tamer — " & modeText) with prompt ("Found " & totalTabs & " tabs. Protected leading tabs are always excluded. Select domains and/or deduplication. Overlapping selections count once.") with multiple selections allowed
    if chosen is false then return "Cancelled. No tabs closed."
    my reportProgress("Preparing preview", "Applying your selection to " & totalTabs & " tabs", totalTabs, 0)
    set actions to my resolveSelection(optionsList, ranked, dupeOption, duplicateCount > 0, chosen)
    set plan to my makePlan(allTabs, chosenDomains of actions, wantsDedupe of actions)
    set closeCount to count of plan
    set reportText to my previewText(totalTabs, plan)
    my clearProgress()
    if not applyMode then
        display dialog ("DRY RUN — no tabs closed and no backup written." & return & return & reportText & return & return & "To enable cleanup, run again with --apply.") with title "Safari Tab Tamer" buttons {"OK"} default button "OK"
        return "Dry run: " & closeCount & " candidate tabs. No tabs closed."
    end if
    if closeCount = 0 then
        display dialog "Nothing to close." buttons {"OK"} default button "OK"
        return "Nothing to close."
    end if
    display dialog (reportText & return & return & "This will close tabs. Ensure your manual pinned counts are correct. Save any unsaved work. Do not change Safari windows, tabs, or Tab Groups during cleanup." & return & return & "A private URL backup must pass verification first.") with title "Confirm cleanup" buttons {"Cancel", "Back up and close"} default button "Cancel" cancel button "Cancel" with icon caution
    -- Abort if the scan went stale while the user reviewed the plan.
    my reportProgress("Checking Safari", "Verifying the scan before creating the backup", 0, 0)
    my requireSnapshot(snapshot)
    set backupRoot to (current application's NSHomeDirectory() as text) & "/Library/Application Support/Safari Tab Tamer/Backups"
    my reportProgress("Saving backup", "Writing and verifying the complete URL inventory", 0, 0)
    set backupPath to my writeBackup(snapshot, allTabs, plan, backupRoot)
    set resultText to my applyPlan(snapshot, plan)
    my clearProgress()
    display dialog (resultText & return & return & "URL backup: " & backupPath & return & return & "A URL backup cannot restore unsaved work or full Safari sessions.") with title "Safari Tab Tamer" buttons {"OK"} default button "OK"
    return resultText & linefeed & "Backup: " & backupPath
end interactiveRun

on windowHint(urlList)
    set hintText to "Leading URLs (to help identify this window):"
    set sampleCount to count of urlList
    if sampleCount > 3 then set sampleCount to 3
    repeat with i from 1 to sampleCount
        set u to item i of urlList
        if u = "" then set u to "[no URL]"
        if (length of u) > 100 then set u to (text 1 thru 100 of u) & "…"
        set hintText to hintText & return & i & ": " & u
    end repeat
    return hintText
end windowHint

on askProtectedCount(wid, tabTotal, hintText)
    repeat
        set answer to display dialog ("Window ID " & wid & " — " & tabTotal & " tabs" & return & hintText & return & return & "How many tabs at the LEFT of this window must be protected? Include every pinned tab, plus any extra leading tabs you want to keep." & return & return & "Enter 0 explicitly if none. Pinned status is NOT detected automatically.") default answer "" with title "Protect pinned tabs manually" buttons {"Cancel", "Protect"} default button "Cancel" cancel button "Cancel"
        set rawCount to text returned of answer
        if my validCount(rawCount, tabTotal) then return rawCount as integer
        display alert "Enter a whole number from 0 to " & tabTotal
    end repeat
end askProtectedCount

on validCount(rawCount, maximumCount)
    if rawCount = "" then return false
    repeat with c in characters of rawCount
        if (contents of c) is not in "0123456789" then return false
    end repeat
    try
        set n to rawCount as integer
        return n ≥ 0 and n ≤ maximumCount
    on error
        return false
    end try
end validCount

-- One batched URL fetch per window. No JavaScript, UI scripting, or session DB access.
on readSnapshot()
    return my readSnapshotWithProgress(false)
end readSnapshot

on readSnapshotWithProgress(showProgress)
    if application "Safari" is not running then error "Safari quit. No further close commands sent."
    if showProgress then my reportProgress("Scanning Safari", "Waiting for the window list (up to 300 seconds)", 0, 0)
    tell application "Safari"
        with timeout of 300 seconds
            set windowIDs to id of every window
        end timeout
    end tell
    set resultList to {}
    set scannedWindows to 0
    set scannedTabs to 0
    repeat with idRef in windowIDs
        set wid to contents of idRef
        if showProgress then my reportProgress("Scanning Safari", "Reading window " & (scannedWindows + 1) & " of " & (count of windowIDs) & "; " & scannedTabs & " tabs read. Waiting for Safari may take up to 300 seconds.", count of windowIDs, scannedWindows)
        try
            tell application "Safari"
                with timeout of 300 seconds
                    set rawURLs to URL of every tab of window id wid
                end timeout
            end tell
        on error errMsg number errNum
            error ("Scan failed for window ID " & wid & ". " & errMsg) number errNum
        end try
        set cleanURLs to {}
        repeat with u in rawURLs
            if contents of u is missing value then
                set end of cleanURLs to ""
            else
                set end of cleanURLs to contents of u as text
            end if
        end repeat
        set end of resultList to {windowID:wid, tabURLs:cleanURLs, protectedCount:0}
        set scannedWindows to scannedWindows + 1
        set scannedTabs to scannedTabs + (count of cleanURLs)
    end repeat
    if showProgress then my clearProgress()
    return resultList
end readSnapshotWithProgress

on inventory(snapshot)
    return my inventoryWithProgress(snapshot, false)
end inventory

on inventoryWithProgress(snapshot, showProgress)
    set allTabs to {}
    set seenURLs to current application's NSMutableSet's |set|()
    set totalTabs to 0
    repeat with w in snapshot
        set totalTabs to totalTabs + (count of tabURLs of w)
    end repeat
    if showProgress then my reportProgress("Analyzing tabs", "Preserving protected copies", totalTabs, 0)
    -- Protected copies take precedence regardless of window enumeration order.
    repeat with w in snapshot
        repeat with i from 1 to protectedCount of w
            set u to item i of tabURLs of w
            -- Non-web protected URLs cannot affect cleanup; no parsing is needed here.
            seenURLs's addObject:u
        end repeat
    end repeat
    set analyzedTabs to 0
    repeat with w in snapshot
        repeat with i from 1 to count of tabURLs of w
            set u to item i of tabURLs of w
            set h to my hostnameOf(u)
            set keepTab to i ≤ protectedCount of w
            set isDupe to false
            if h is not "" and not keepTab then
                set isDupe to (seenURLs's containsObject:u) as boolean
                seenURLs's addObject:u
            end if
            set end of allTabs to {windowID:windowID of w, tabIndex:i, tabURL:u, hostName:h, isProtected:keepTab, isDuplicate:isDupe}
            set analyzedTabs to analyzedTabs + 1
            if showProgress and (analyzedTabs mod 100 = 0 or analyzedTabs = totalTabs) then my reportProgress("Analyzing tabs", analyzedTabs & " of " & totalTabs & " URLs analyzed", totalTabs, analyzedTabs)
        end repeat
    end repeat
    return allTabs
end inventoryWithProgress

on hostnameOf(rawURL)
    if rawURL = "" then return ""
    set parts to current application's NSURLComponents's componentsWithString:rawURL
    if parts is missing value then return ""
    set urlScheme to parts's |scheme|()
    if urlScheme is missing value then return ""
    set urlScheme to urlScheme's lowercaseString() as text
    if urlScheme is not "http" and urlScheme is not "https" then return ""
    set h to parts's |host|()
    if h is missing value then return ""
    set h to h's lowercaseString() as text
    if h starts with "www." and (length of h) > 4 then set h to text 5 thru -1 of h
    return h
end hostnameOf

on rankDomains(allTabs)
    set counts to current application's NSMutableDictionary's dictionary()
    repeat with t in allTabs
        set h to hostName of t
        if h is not "" then
            set oldCount to counts's objectForKey:h
            if oldCount is missing value then set oldCount to 0
            counts's setObject:((oldCount as integer) + 1) forKey:h
        end if
    end repeat
    set rows to current application's NSMutableArray's array()
    repeat with h in (counts's allKeys() as list)
        set d to current application's NSMutableDictionary's dictionary()
        d's setObject:(contents of h) forKey:"host"
        d's setObject:(counts's objectForKey:(contents of h)) forKey:"count"
        rows's addObject:d
    end repeat
    set byCount to current application's NSSortDescriptor's sortDescriptorWithKey:"count" ascending:false
    set byHost to current application's NSSortDescriptor's sortDescriptorWithKey:"host" ascending:true selector:"compare:"
    set orderedRows to rows's sortedArrayUsingDescriptors:{byCount, byHost}
    set resultList to {}
    repeat with d in orderedRows
        set end of resultList to {hostName:(d's objectForKey:"host") as text, tabCount:(d's objectForKey:"count") as integer}
    end repeat
    return resultList
end rankDomains

on affectedDomainCounts(allTabs, showProgress)
    -- Count each eligible hostname once, then accumulate dot-boundary suffixes.
    -- The menu must not rebuild the entire close plan for every domain.
    set eligibleCounts to current application's NSMutableDictionary's dictionary()
    set tabTotal to count of allTabs
    set processedTabs to 0
    if showProgress then my reportProgress("Preparing domain list", "Counting eligible tabs", tabTotal, 0)
    repeat with tabRef in allTabs
        set t to contents of tabRef
        set h to hostName of t
        if not isProtected of t and h is not "" then
            set oldCount to eligibleCounts's objectForKey:h
            if oldCount is missing value then set oldCount to 0
            eligibleCounts's setObject:((oldCount as integer) + 1) forKey:h
        end if
        set processedTabs to processedTabs + 1
        if showProgress and (processedTabs mod 100 = 0 or processedTabs = tabTotal) then my reportProgress("Preparing domain list", processedTabs & " of " & tabTotal & " tabs counted", tabTotal, processedTabs)
    end repeat
    set affectedCounts to current application's NSMutableDictionary's dictionary()
    set hostList to eligibleCounts's allKeys() as list
    set processedHosts to 0
    repeat with hostRef in hostList
        set h to contents of hostRef
        set eligibleCount to (eligibleCounts's objectForKey:h) as integer
        set suffixText to current application's NSString's stringWithString:h
        repeat while (suffixText's |length|() as integer) > 0
            set oldCount to affectedCounts's objectForKey:suffixText
            if oldCount is missing value then set oldCount to 0
            affectedCounts's setObject:((oldCount as integer) + eligibleCount) forKey:suffixText
            -- Avoid bridging the enormous NSNotFound sentinel through AppleScript.
            if not ((suffixText's containsString:".") as boolean) then exit repeat
            set dotRange to suffixText's rangeOfString:"."
            set dotPosition to location of dotRange
            set suffixText to suffixText's substringFromIndex:(dotPosition + 1)
        end repeat
        set processedHosts to processedHosts + 1
        if showProgress and (processedHosts mod 50 = 0 or processedHosts = (count of hostList)) then my reportProgress("Preparing domain list", processedHosts & " of " & (count of hostList) & " hostnames grouped", count of hostList, processedHosts)
    end repeat
    return affectedCounts
end affectedDomainCounts

on matchesDomain(h, selectedDomains)
    if h = "" then return false
    repeat with d in selectedDomains
        set targetDomain to contents of d
        if h is targetDomain or h ends with ("." & targetDomain) then return true
    end repeat
    return false
end matchesDomain

on makePlan(allTabs, selectedDomains, doDedupe)
    set resultList to {}
    repeat with t in allTabs
        if not isProtected of t and hostName of t is not "" then
            if my matchesDomain(hostName of t, selectedDomains) or (doDedupe and isDuplicate of t) then set end of resultList to contents of t
        end if
    end repeat
    return resultList
end makePlan

on resolveSelection(optionsList, ranked, dupeOption, hasDupeOption, chosen)
    set selectedDomains to {}
    set doDedupe to hasDupeOption and (dupeOption is in chosen)
    set rowOffset to 0
    if hasDupeOption then set rowOffset to 1
    repeat with i from 1 to count of ranked
        if item (i + rowOffset) of optionsList is in chosen then set end of selectedDomains to hostName of item i of ranked
    end repeat
    return {chosenDomains:selectedDomains, wantsDedupe:doDedupe}
end resolveSelection

on previewText(totalTabs, plan)
    set resultText to ((count of plan) as text) & " of " & totalTabs & " tabs selected for closure." & return & "Selected tabs by hostname (subdomain matches included; protected tabs excluded):" & return
    repeat with row in my rankDomains(plan)
        set resultText to resultText & return & (tabCount of row as text) & " | " & hostName of row
    end repeat
    return resultText
end previewText

-- Compare URL strings through Foundation, never AppleScript's case-insensitive `is`.
on exactText(a, b)
    return ((current application's NSString's stringWithString:a)'s isEqualToString:b) as boolean
end exactText

on sameURLs(a, b)
    if (count of a) is not (count of b) then return false
    repeat with i from 1 to count of a
        if not my exactText(item i of a, item i of b) then return false
    end repeat
    return true
end sameURLs

on sameSnapshot(expected, actual)
    if (count of expected) is not (count of actual) then return false
    repeat with w in expected
        set matched to false
        repeat with otherWindow in actual
            if windowID of w = windowID of otherWindow then
                if not my sameURLs(tabURLs of w, tabURLs of otherWindow) then return false
                set matched to true
                exit repeat
            end if
        end repeat
        if not matched then return false
    end repeat
    return true
end sameSnapshot

on requireSnapshot(expected)
    if not my sameSnapshot(expected, my readSnapshot()) then error "Safari's windows or ordered URLs changed. No further close commands sent. Start a fresh scan."
end requireSnapshot

on withoutClosedTab(snapshot, wid, idx)
    set resultList to {}
    repeat with w in snapshot
        if windowID of w = wid then
            set remainingURLs to {}
            repeat with i from 1 to count of tabURLs of w
                if i is not idx then set end of remainingURLs to item i of tabURLs of w
            end repeat
            -- Closing the final tab can remove the window.
            if (count of remainingURLs) > 0 then set end of resultList to {windowID:wid, tabURLs:remainingURLs, protectedCount:protectedCount of w}
        else
            set end of resultList to contents of w
        end if
    end repeat
    return resultList
end withoutClosedTab

on applyPlan(snapshot, plan)
    set expected to snapshot
    set confirmedCount to 0
    set issuedCount to 0
    set lastError to ""
    -- inventory/plan retain window order and ascending indices; reverse prevents shifts.
    repeat with i from (count of plan) to 1 by -1
        set t to item i of plan
        try
            my reportProgress("Closing selected tabs", "Checking Safari before tab " & (confirmedCount + 1) & " of " & (count of plan) & ". A Safari response may take up to 300 seconds.", count of plan, confirmedCount)
            my requireSnapshot(expected)
            set wid to windowID of t
            set idx to tabIndex of t
            tell application "Safari"
                with timeout of 300 seconds
                    set currentURL to URL of tab idx of window id wid
                end timeout
            end tell
            if currentURL is missing value then set currentURL to ""
            if not my exactText(currentURL as text, tabURL of t) then error "Target URL changed."
            set issuedCount to issuedCount + 1
            tell application "Safari"
                with timeout of 300 seconds
                    close tab idx of window id wid
                end timeout
            end tell
            set nextExpected to my withoutClosedTab(expected, wid, idx)
            my requireSnapshot(nextExpected)
            set expected to nextExpected
            set confirmedCount to confirmedCount + 1
            my reportProgress("Closing selected tabs", confirmedCount & " closures verified", count of plan, confirmedCount)
        on error errMsg number errNum
            set lastError to "Stopped at error " & errNum & ": " & errMsg & return & "An outstanding close may still complete, especially after a timeout. Let Safari settle, then start a fresh scan. No automatic retry."
            exit repeat
        end try
    end repeat
    set resultText to "Verified closures: " & confirmedCount & return & "Close commands issued: " & issuedCount & return & "Planned: " & (count of plan)
    if lastError is not "" then set resultText to resultText & return & return & lastError
    return resultText
end applyPlan

-- Explicit JSON keys avoid record coercion ambiguity and safely escape URLs.
on tabJSON(t)
    set d to current application's NSMutableDictionary's dictionary()
    d's setObject:(windowID of t) forKey:"window_id"
    d's setObject:(tabIndex of t) forKey:"tab_index"
    d's setObject:(tabURL of t) forKey:"url"
    d's setObject:(hostName of t) forKey:"hostname"
    d's setObject:(isProtected of t) forKey:"protected"
    d's setObject:(isDuplicate of t) forKey:"duplicate"
    return d
end tabJSON

on backupData(snapshot, allTabs, plan)
    set root to current application's NSMutableDictionary's dictionary()
    root's setObject:"1.0.0" forKey:"version"
    root's setObject:1 forKey:"schema_version"
    set formatter to current application's NSISO8601DateFormatter's new()
    root's setObject:(formatter's stringFromDate:(current application's NSDate's dateWithTimeIntervalSinceNow:0)) forKey:"created_at"
    root's setObject:"URL inventory only; not a complete Safari session. Pinned protection is manual." forKey:"limitations"
    set windowEntries to current application's NSMutableArray's array()
    repeat with w in snapshot
        set d to current application's NSMutableDictionary's dictionary()
        d's setObject:(windowID of w) forKey:"window_id"
        d's setObject:(protectedCount of w) forKey:"protected_leading_tabs"
        d's setObject:(tabURLs of w) forKey:"urls"
        windowEntries's addObject:d
    end repeat
    root's setObject:windowEntries forKey:"windows"
    set tabEntries to current application's NSMutableArray's array()
    repeat with t in allTabs
        tabEntries's addObject:(my tabJSON(contents of t))
    end repeat
    root's setObject:tabEntries forKey:"tabs"
    set planned to current application's NSMutableArray's array()
    repeat with t in plan
        planned's addObject:(my tabJSON(contents of t))
    end repeat
    root's setObject:planned forKey:"planned_closures"
    set {jsonData, jsonError} to current application's NSJSONSerialization's dataWithJSONObject:root options:(current application's NSJSONWritingPrettyPrinted) |error|:(reference)
    if jsonData is missing value then error "Cannot encode URL backup."
    return jsonData
end backupData

on ensurePrivateDirectory(fm, dirPath, createParents)
    if not (fm's fileExistsAtPath:dirPath) then
        set attrs to current application's NSDictionary's dictionaryWithObject:448 forKey:(current application's NSFilePosixPermissions)
        set {ok, e} to fm's createDirectoryAtPath:dirPath withIntermediateDirectories:createParents attributes:attrs |error|:(reference)
        if not ok then error "Cannot create private backup directory."
    end if
    set {attrs, e} to fm's attributesOfItemAtPath:dirPath |error|:(reference)
    if attrs is missing value then error "Cannot inspect backup directory."
    if not my exactText((attrs's objectForKey:(current application's NSFileType)) as text, (current application's NSFileTypeDirectory) as text) then error "Backup directory is not a regular directory (symlinks are refused)."
    if not my exactText((attrs's objectForKey:(current application's NSFileOwnerAccountName)) as text, current application's NSUserName() as text) then error "Backup directory has a different owner."
    set perms to current application's NSDictionary's dictionaryWithObject:448 forKey:(current application's NSFilePosixPermissions)
    set {ok, e} to fm's setAttributes:perms ofItemAtPath:dirPath |error|:(reference)
    if not ok then error "Cannot restrict backup directory permissions."
    set {attrs, e} to fm's attributesOfItemAtPath:dirPath |error|:(reference)
    if attrs is missing value then error "Cannot verify backup directory permissions."
    if ((attrs's objectForKey:(current application's NSFilePosixPermissions)) as integer) is not 448 then error "Backup directory permissions are not 0700."
end ensurePrivateDirectory

on writeBackup(snapshot, allTabs, plan, backupRoot)
    set jsonData to my backupData(snapshot, allTabs, plan)
    set fm to current application's NSFileManager's defaultManager()
    my ensurePrivateDirectory(fm, backupRoot, true)
    set uniqueDir to backupRoot & "/" & (current application's NSUUID's UUID()'s UUIDString() as text)
    if (fm's fileExistsAtPath:uniqueDir) then error "Backup path collision."
    my ensurePrivateDirectory(fm, uniqueDir, false)
    set backupPath to uniqueDir & "/tabs.json"
    if (fm's fileExistsAtPath:backupPath) then error "Refusing to overwrite a backup."
    -- The private UUID directory protects the atomic file during creation/chmod.
    set {ok, e} to jsonData's writeToFile:backupPath options:(current application's NSDataWritingAtomic) |error|:(reference)
    if not ok then error "Backup write failed. No close commands sent."
    set perms to current application's NSDictionary's dictionaryWithObject:384 forKey:(current application's NSFilePosixPermissions)
    set {ok, e} to fm's setAttributes:perms ofItemAtPath:backupPath |error|:(reference)
    if not ok then error "Cannot restrict backup file permissions."
    set {attrs, e} to fm's attributesOfItemAtPath:backupPath |error|:(reference)
    if attrs is missing value then error "Cannot inspect backup file."
    if ((attrs's objectForKey:(current application's NSFilePosixPermissions)) as integer) is not 384 then error "Backup file permissions are not 0600."
    set readback to current application's NSData's dataWithContentsOfFile:backupPath
    if readback is missing value then error "Cannot read backup back."
    if not (jsonData's isEqualToData:readback) then error "Backup readback does not match."
    set {decoded, e} to current application's NSJSONSerialization's JSONObjectWithData:readback options:0 |error|:(reference)
    if decoded is missing value then error "Backup JSON verification failed."
    return backupPath
end writeBackup

on assertThat(condition, messageText)
    if not condition then error "Self-test failed: " & messageText
end assertThat

on selfTest()
    my assertThat(my launchArguments({"--apply"}) = {"--apply"}, "native CLI argument list preserved")
    my assertThat((count of my launchArguments(current application)) = 0, "GUI application argument defaults to dry run")
    my assertThat((count of my launchArguments(me)) = 0, "GUI script argument defaults to dry run")
    my assertThat((count of my launchArguments(missing value)) = 0, "missing GUI argument defaults to dry run")
    my assertThat((count of my launchArguments(current application's NSString's stringWithString:"--apply")) = 0, "Cocoa text cannot enable apply mode")
    my assertThat((count of my launchArguments(current application's NSArray's arrayWithObject:"--apply")) = 0, "Cocoa collections cannot enable apply mode")
    my assertThat(not my exactText("https://x.test/A", "https://x.test/a"), "case-sensitive URL equality")
    my assertThat(my hostnameOf("HTTPS://WWW.Example.COM/A") = "example.com", "hostname normalization")
    my assertThat(my hostnameOf("file:///tmp/a") = "", "non-HTTP exclusion")
    my assertThat(my hostnameOf("not a URL") = "", "malformed URL exclusion")
    my assertThat(my matchesDomain("sub.example.com", {"example.com"}), "subdomain match")
    my assertThat(not my matchesDomain("badexample.com", {"example.com"}), "domain boundary")
    my assertThat(not my matchesDomain("example.com.evil.test", {"example.com"}), "domain suffix boundary")
    my assertThat(not my validCount("", 3), "explicit pinned count required")
    my assertThat(not my validCount("1.5", 3), "integer pinned count")
    my assertThat(not my validCount("4", 3), "pinned count range")
    my assertThat(my validCount("0", 3), "explicit zero allowed")
    set fixture to {{windowID:11, tabURLs:{"https://example.com/A", "https://example.com/a", "https://example.com/A", "https://example.com/p?x=1", "https://example.com/p?x=1#f", "https://example.com/p?x=1&utm_source=x", "https://example.com/p?a=1&b=2", "https://example.com/p?b=2&a=1", "https://example.com/p/", "file:///tmp/a", ""}, protectedCount:0}, {windowID:22, tabURLs:{"https://example.com/A", "https://sub.example.com/", "https://z.test/"}, protectedCount:1}}
    set tabs to my inventory(fixture)
    set plan to my makePlan(tabs, {}, true)
    my assertThat((count of plan) = 2, "exact dedupe, protected keeper across windows, URL variants retained")
    my assertThat(my previewText(14, plan) starts with "2 of 14 tabs", "nonempty preview count")
    my assertThat(my previewText(14, {}) starts with "0 of 14 tabs", "empty preview count")
    set menuRows to {{hostName:"a.test", tabCount:1}, {hostName:"z.test", tabCount:1}}
    set menuChoice to my resolveSelection({"duplicates", "a", "z"}, menuRows, "duplicates", true, {"duplicates", "z"})
    my assertThat(chosenDomains of menuChoice = {"z.test"} and wantsDedupe of menuChoice, "selection mapping with dedupe offset")
    set menuChoice to my resolveSelection({"a", "z"}, menuRows, "duplicates", false, {"a"})
    my assertThat(chosenDomains of menuChoice = {"a.test"} and not wantsDedupe of menuChoice, "selection mapping without dedupe offset")
    set pinFixture to {{windowID:7, tabURLs:{"https://x.test/", "https://x.test/"}, protectedCount:0}}
    repeat with winRef in pinFixture
        set protectedCount of winRef to 1
    end repeat
    my assertThat(protectedCount of item 1 of pinFixture = 1, "manual protection updates snapshot record")
    my assertThat((count of my makePlan(my inventory(pinFixture), {"x.test"}, true)) = 1, "manual prefix affects the plan")
    my assertThat(tabIndex of item 1 of plan = 1 and tabIndex of item 2 of plan = 3, "protected keeper preferred")
    set ranked to my rankDomains(tabs)
    my assertThat(hostName of item 1 of ranked = "example.com" and tabCount of item 1 of ranked = 10, "ranking counts")
    set tied to my rankDomains(my inventory({{windowID:1, tabURLs:{"https://z.test/", "https://a.test/"}, protectedCount:0}}))
    my assertThat(hostName of item 1 of tied = "a.test", "ranking tie order")
    set domainPlan to my makePlan(tabs, {"example.com"}, true)
    my assertThat((count of domainPlan) = 10, "domain union deduped and protected/non-web excluded")
    set menuCounts to my affectedDomainCounts(tabs, false)
    my assertThat(((menuCounts's objectForKey:"example.com") as integer) = 10, "menu includes subdomains and excludes protected tabs")
    set hostFixture to {{windowID:31, tabURLs:{"https://example.com/keep", "https://protected.test/"}, protectedCount:2}, {windowID:32, tabURLs:{"https://a.example.com/", "https://deep.a.example.com/", "https://badexample.com/", "https://example.com.evil.test/", "https://a.protected.test/", "http://localhost/", "http://127.0.0.1/", "http://[::1]/", "https://example.com./", "https://a..example.com/", "file:///tmp/a", ""}, protectedCount:0}}
    set hostTabs to my inventory(hostFixture)
    set menuCounts to my affectedDomainCounts(hostTabs, false)
    repeat with row in my rankDomains(hostTabs)
        set h to hostName of row
        set optimizedCount to menuCounts's objectForKey:h
        if optimizedCount is missing value then set optimizedCount to 0
        my assertThat((optimizedCount as integer) = (count of my makePlan(hostTabs, {h}, false)), "optimized menu count preserves matching for " & h)
    end repeat
    my assertThat(my sameSnapshot(fixture, {item 2 of fixture, item 1 of fixture}), "window order irrelevant")
    my assertThat(not my sameURLs({"https://x.test/A"}, {"https://x.test/a"}), "case-sensitive stale scan guard")
    my assertThat(not my sameURLs({"a", "b"}, {"b", "a"}), "ordered URL guard")
    my assertThat(not my sameSnapshot(fixture, {item 1 of fixture}), "missing window guard")
    set afterClose to my withoutClosedTab(fixture, 11, 3)
    my assertThat((count of tabURLs of item 1 of afterClose) = 10, "reverse-index snapshot update")
    set emptyAfter to my withoutClosedTab({{windowID:3, tabURLs:{"https://x.test/"}, protectedCount:0}}, 3, 1)
    my assertThat((count of emptyAfter) = 0, "last-tab window removal")
    set tempRoot to (current application's NSTemporaryDirectory() as text) & "safari-tab-tamer-test-" & (current application's NSUUID's UUID()'s UUIDString() as text)
    set fm to current application's NSFileManager's defaultManager()
    try
        set path1 to my writeBackup(fixture, tabs, plan, tempRoot)
        set path2 to my writeBackup(fixture, tabs, plan, tempRoot)
        my assertThat(not my exactText(path1, path2), "collision-resistant backup names")
        set bytes to current application's NSData's dataWithContentsOfFile:path1
        set {decoded, e} to current application's NSJSONSerialization's JSONObjectWithData:bytes options:0 |error|:(reference)
        my assertThat(((decoded's objectForKey:"tabs")'s |count|() as integer) = 14, "complete JSON inventory")
        my assertThat(((decoded's objectForKey:"planned_closures")'s |count|() as integer) = 2, "JSON close plan")
        set unusualURL to "https://x.test/" & quote & "quoted" & quote & tab & linefeed & "ü"
        set unusual to {{windowID:1, tabURLs:{unusualURL}, protectedCount:0}}
        set unusualData to my backupData(unusual, {}, {})
        set {unusualJSON, e} to current application's NSJSONSerialization's JSONObjectWithData:unusualData options:0 |error|:(reference)
        set recoveredURL to (((unusualJSON's objectForKey:"windows")'s objectAtIndex:0)'s objectForKey:"urls")'s objectAtIndex:0
        my assertThat(my exactText(unusualURL, recoveredURL as text), "JSON escaping and Unicode round trip")
        set refused to false
        try
            my writeBackup(fixture, tabs, plan, "/dev/null")
        on error
            set refused to true
        end try
        my assertThat(refused, "invalid backup destination fails closed")
        set {ok, e} to fm's removeItemAtPath:tempRoot |error|:(reference)
        if not ok then error "Cannot remove self-test temporary files."
    on error errMsg number errNum
        fm's removeItemAtPath:tempRoot |error|:(missing value)
        error errMsg number errNum
    end try
    return "PASS: GUI/CLI entry arguments, URL semantics, domain ranking, protected keepers, optimized menu counts, selection mapping, preview rendering, plan union, stale-scan guards, JSON backups, private permissions, unique paths, and fail-closed destination. No Safari access."
end selfTest
