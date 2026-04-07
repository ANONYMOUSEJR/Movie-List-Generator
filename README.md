

# Movie List Generator

A PowerShell script that generates a numbered markdown list of directories with dynamic zero-padding. It features customizable ignore and recurse lists, partial-match skipping, automatic change detection, and colorized console output.

## Features

* Generates a dynamically zero-padded numbered markdown list of folders to a file named `MovieList.md`.

* Overwrites the output file on each run to prevent duplicates.

* Compares the new list against the previous list to detect new additions and removed entries.

* Logs changes to the output file conditionally, controlled by the `$LogChangesToFile` setting.

* Displays colorized console output for standard folders, recursed subfolders, warnings, and changes.

* Allows disabling ANSI colors by setting the environment variable `$env:NOANSI = '1'`.

* Supports an `$IgnoreList` to completely skip specific folders. Entries also apply as partial matches inside recursed containers.

* Supports a `$RecurseList` to treat specific folders as containers, listing all subfolders recursively while skipping the container itself.

* Supports a `$RecurseSkipList` to ignore items during recursion based on partial name matches.

* Validates `$RecurseList` entries and displays warnings and a boxed error summary for missing directories.

* Uses O(1) HashSet lookups for ignore, recurse, and change detection operations.

* Writes the output file in a single call using UTF-8 without BOM.

## Installation & Usage

1. Place `MovieListGenerator.ps1` in the root directory containing the folders you want to list. All paths are relative to the folder where the script lives.

2. Run the script via PowerShell:
   ```powershell
   .\MovieListGenerator.ps1
   ```

3. The generated list will be saved as `MovieList.md` in the same directory.

> **Note:** If your execution policy blocks the script, you can run it with:
> ```powershell
> powershell -ExecutionPolicy Bypass -File .\MovieListGenerator.ps1
> ```

## Configuration

Configuration is handled by editing the arrays and option variable directly inside the `.ps1` file.

### Lists

Edit the three arrays near the top of the script: `$IgnoreList`, `$RecurseList`, and `$RecurseSkipList`.

* Use one entry per line as a quoted string inside the array.

* `$IgnoreList` entries match exactly against top-level folder names and partially against relative paths inside recursed containers.

* `$RecurseList` entries must match existing top-level directory names exactly. Missing entries will produce warnings.

* `$RecurseSkipList` entries match partially (case-insensitive) against leaf folder names during recursion.

```powershell
$IgnoreList = @(
    'ANIME'
    'SHOWS'
)

$RecurseList = @(
    'The Naked Gun'
    'Kung Fu Panda'
)

$RecurseSkipList = @(
    'Subs'
    'Sample'
)
```

### Options

* `$LogChangesToFile = $true` — Appends the "New Additions" and "Removed Entries" sections to the output markdown file.

* `$LogChangesToFile = $false` — Keeps the output file clean and only displays the changes in the console.

## License

[MIT License](https://github.com/ANONYMOUSEJR/Movie-List-Generator/tree/main?tab=MIT-1-ov-file#readme)
