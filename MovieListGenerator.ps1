# MovieListGenerator.ps1
#
# ============================================================
# WHAT THIS DOES
# - Overwrites MovieList.md each run (no appending/duplicates)
# - Numbers correctly with dynamic zero-padding based on total count
# - Prints folder list to console (stdout) AND writes to file
# - Supports an IGNORE list (skip, do not count) - also applies inside RECURSE folders
# - Supports a RECURSE list (treat as containers: list all subfolders recursively; skip the container itself)
# - Supports a RECURSE-SKIP list for partial name matches to ignore during recursion (e.g., "Subs", "[Judas]")
# - Validates RECURSE entries; missing entries produce warnings and a boxed summary at the end
# - Compares new list against previous list (if exists) to detect:
#     * NEW ADDITIONS: folders present in new list but not in old
#     * REMOVED ENTRIES: folders present in old list but not in new
#   These changes are always displayed in the console output.
#   Writing changes to the output file is controlled by $LogChangesToFile option.
# - Colorized console:
#     * Normal folder lines -> GREEN
#     * Recursed subfolder lines -> ORANGE/YELLOW (parents) + GREEN (leaf); '\' in PINK
#     * Warnings/Errors -> written via $Host.UI.WriteErrorLine (host-rendered, legacy-safe)
#     * Box separators -> PURPLE
#     * New additions -> CYAN
#     * Removed entries -> RED
#
# HOW TO EDIT THE LISTS
# - Scroll to the bottom of this file and edit the three arrays:
#     $IgnoreList, $RecurseList, $RecurseSkipList
# - One entry per line, as a quoted string in the array.
#
# OPTIONS
# - $LogChangesToFile: $true  -> append additions/removals to output file
#                      $false -> only show them in console (file stays clean)
#
# NOTES
# - All paths are relative to the folder where this .ps1 lives.
# - Set $env:NOANSI = '1' before running to suppress all color output.
# ============================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Always operate from the script's own directory ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ScriptDir

$RootPrefix = $ScriptDir.TrimEnd('\')

$OutputFile = Join-Path $RootPrefix 'MovieList.md'

# --- Warn if no existing movie list file is found ---
if (-not (Test-Path -LiteralPath $OutputFile)) {
    $Host.UI.WriteErrorLine("[WARN] No existing movie list found at: `"$OutputFile`"")
    $Host.UI.WriteErrorLine("       A new file will be created.")
}

# ============================================================
# USER CONFIGURATION — edit these three arrays and the option below
# ============================================================

$IgnoreList = @(
)

# Container folders: the container itself is not listed,
# but all of its subfolders recursively ARE listed with relative paths.
$RecurseList = @(
)

# Partial name matches (case-insensitive) to skip during recursion.
$RecurseSkipList = @(
)

# $true  -> append additions/removals sections to the output file
# $false -> only display changes in console; keep output file clean
$LogChangesToFile = $true

# ============================================================
# ANSI colors
# ============================================================
$NoAnsi = ($env:NOANSI -eq '1')

if ($NoAnsi) {
    $C = @{ Red=''; Grn=''; Org=''; Pnk=''; Prp=''; Cyn=''; Rst='' }
} else {
    $e = [char]0x1B
    $C = @{
        Red = "$e[31m"
        Grn = "$e[32m"
        Org = "$e[93m"
        Pnk = "$e[95m"
        Prp = "$e[35m"
        Cyn = "$e[96m"
        Rst = "$e[0m"
    }
}

# ============================================================
# Build O(1) lookup sets
# ============================================================
$IgnoreSet = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]$IgnoreList,
    [System.StringComparer]::OrdinalIgnoreCase
)

$RecurseSet = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]$RecurseList,
    [System.StringComparer]::OrdinalIgnoreCase
)

# ============================================================
# Helper: partial match against a list (case-insensitive)
# ============================================================
function Test-PartialMatch {
    param(
        [string]$Subject,
        [string[]]$Patterns
    )
    foreach ($pattern in $Patterns) {
        if ($Subject.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            return $true
        }
    }
    return $false
}

# ============================================================
# Helper: build colorized path string for recursed entries
# Parents -> ORANGE, backslash -> PINK, leaf -> GREEN
# ============================================================
function Format-ColorizedPath {
    param([string]$RelPath)
    $parts = $RelPath.Split('\')
    $sb = [System.Text.StringBuilder]::new()
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($i -lt $parts.Count - 1) {
            [void]$sb.Append("$($C.Org)$($parts[$i])$($C.Rst)$($C.Pnk)\$($C.Rst)")
        } else {
            [void]$sb.Append("$($C.Grn)$($parts[$i])$($C.Rst)")
        }
    }
    return $sb.ToString()
}

# ============================================================
# Validate RECURSE entries exist on disk; collect missing ones
# ============================================================
$ErrorFlag       = $false
$MissingRecurse  = [System.Collections.Generic.List[string]]::new()

foreach ($entry in $RecurseList) {
    $path = Join-Path $RootPrefix $entry
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        $ErrorFlag = $true
        $MissingRecurse.Add($entry)
        $Host.UI.WriteErrorLine("[WARN] Recurse entry not found: `"$entry`"")
    }
}

# ============================================================
# Extract old entries from existing output file (for change detection)
# Skips header lines and any previously logged change sections
# ============================================================
$OldEntries = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

if (Test-Path -LiteralPath $OutputFile) {
    $oldLines        = [System.IO.File]::ReadAllLines($OutputFile)
    $inChangeSection = $false

    # Skip line 0 (header) and line 1 (separator)
    for ($i = 2; $i -lt $oldLines.Count; $i++) {
        $line = $oldLines[$i].Trim()
        if ($line.Length -eq 0) { continue }

        # Entering a change-tracking section
        if ($line -match '^(New Additions:|Removed Entries:|---+)') {
            $inChangeSection = $true
            continue
        }

        # Inside a change-tracking section: skip bullet lines
        if ($inChangeSection) {
            if ($line -match '^-\s+') { continue }
            # Non-bullet, non-separator means we are back in the main list
            $inChangeSection = $false
        }

        # Parse "NNN - Folder Name" (the separator is " - ", first occurrence)
        $dashIdx = $line.IndexOf(' - ')
        if ($dashIdx -ge 0) {
            $entry = $line.Substring($dashIdx + 3).Trim()
            if ($entry.Length -gt 0) {
                [void]$OldEntries.Add($entry)
            }
        }
    }
}

# ============================================================
# Single-pass: collect all entries into memory
# ============================================================
$Entries = [System.Collections.Generic.List[PSCustomObject]]::new()

$topDirs = Get-ChildItem -LiteralPath $RootPrefix -Directory | Sort-Object Name

foreach ($dir in $topDirs) {
    $name = $dir.Name

    # Exact ignore check, then partial ignore check
    if ($IgnoreSet.Contains($name) -or (Test-PartialMatch $name $IgnoreList)) {
        continue
    }

    if ($RecurseSet.Contains($name)) {
        # Container: enumerate all subdirectories recursively, skip the container itself
        $subDirs = Get-ChildItem -LiteralPath $dir.FullName -Directory -Recurse |
                   Sort-Object FullName

        foreach ($sub in $subDirs) {
            $leaf = $sub.Name

            # Recurse-skip: partial match on the leaf folder name
            if (Test-PartialMatch $leaf $RecurseSkipList) { continue }

            $rel = $sub.FullName.Substring($RootPrefix.Length + 1)

            # Ignore: partial match on the full relative path
            if (Test-PartialMatch $rel $IgnoreList) { continue }

            $Entries.Add([PSCustomObject]@{
                RelPath    = $rel
                IsRecursed = $true
            })
        }
    } else {
        $Entries.Add([PSCustomObject]@{
            RelPath    = $name
            IsRecursed = $false
        })
    }
}

# ============================================================
# Determine zero-padding width from total count
# ============================================================
$Total = $Entries.Count
$Width = [Math]::Max(1, "$Total".Length)

# ============================================================
# Build output lines list and write console simultaneously
# ============================================================
$fileLines = [System.Collections.Generic.List[string]]::new()
$fileLines.Add('Number - Folder Name')
$fileLines.Add('---------------------------')

$NewEntries = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

# Console header
Write-Host 'Number - Folder Name'
Write-Host "$($C.Prp)_____________________________________________________$($C.Rst)"

$counter = 1
foreach ($entry in $Entries) {
    $num = $counter.ToString().PadLeft($Width, '0')
    $rel = $entry.RelPath
    [void]$NewEntries.Add($rel)

    # Plain line for file
    $fileLines.Add("$num - $rel")

    # Colorized line for console
    if ($entry.IsRecursed) {
        $colored = Format-ColorizedPath $rel
        Write-Host "$($C.Org)$num - $($C.Rst)$colored"
    } else {
        Write-Host "$($C.Grn)$num - $rel$($C.Rst)"
    }

    $counter++
}

Write-Host ''
Write-Host "Movie list has been (re)generated in: `"$OutputFile`""
Write-Host ''

# ============================================================
# Change detection — O(n) via HashSet membership
# Only runs if there was a previous output file to compare against
# ============================================================
$Additions = [System.Collections.Generic.List[string]]::new()
$Removals  = [System.Collections.Generic.List[string]]::new()

if ($OldEntries.Count -gt 0) {
    foreach ($e in $NewEntries) {
        if (-not $OldEntries.Contains($e)) { $Additions.Add($e) }
    }
    foreach ($e in $OldEntries) {
        if (-not $NewEntries.Contains($e)) { $Removals.Add($e) }
    }
}

# --- Additions ---
if ($Additions.Count -gt 0) {
    Write-Host "$($C.Prp)--------------------------------$($C.Rst)"
    Write-Host "$($C.Cyn)New Additions:$($C.Rst)"
    if ($LogChangesToFile) {
        $fileLines.Add('')
        $fileLines.Add('--------------------------------')
        $fileLines.Add('New Additions:')
    }
    foreach ($a in ($Additions | Sort-Object)) {
        Write-Host "$($C.Cyn)- $a$($C.Rst)"
        if ($LogChangesToFile) { $fileLines.Add("- $a") }
    }
    Write-Host "$($C.Prp)--------------------------------$($C.Rst)"
    if ($LogChangesToFile) { $fileLines.Add('--------------------------------') }
    Write-Host ''
}

# --- Removals ---
if ($Removals.Count -gt 0) {
    Write-Host "$($C.Prp)--------------------------------$($C.Rst)"
    Write-Host "$($C.Red)Removed Entries:$($C.Rst)"
    if ($LogChangesToFile) {
        $fileLines.Add('')
        $fileLines.Add('--------------------------------')
        $fileLines.Add('Removed Entries:')
    }
    foreach ($r in ($Removals | Sort-Object)) {
        Write-Host "$($C.Red)- $r$($C.Rst)"
        if ($LogChangesToFile) { $fileLines.Add("- $r") }
    }
    Write-Host "$($C.Prp)--------------------------------$($C.Rst)"
    if ($LogChangesToFile) { $fileLines.Add('--------------------------------') }
    Write-Host ''
}

# ============================================================
# Write output file in a single call — UTF-8 without BOM
# ============================================================
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllLines($OutputFile, $fileLines.ToArray(), $utf8NoBom)

if ($ErrorFlag) {
    $Host.UI.WriteErrorLine('_____________________________________________________')
    if ($MissingRecurse.Count -gt 0) {
        $Host.UI.WriteErrorLine("ERROR: The following RECURSE entries were not found:")
        $Host.UI.WriteErrorLine("  $($MissingRecurse -join ', ')")
        $Host.UI.WriteErrorLine('')
    }
    $Host.UI.WriteErrorLine('_____________________________________________________')
}

# ============================================================
# Pause equivalent
# ============================================================
Read-Host 'Press Enter to close . . .'
