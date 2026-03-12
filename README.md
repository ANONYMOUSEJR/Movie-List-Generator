# Movie List Generator

A Windows batch script that generates a numbered markdown list of directories with dynamic zero-padding. It features customizable ignore and recurse lists, partial-match skipping, automatic change detection, and colorized console output.

## Features

* Generates a dynamically zero-padded numbered markdown list of folders to a file named `MovieList.md`.


* Overwrites the output file on each run to prevent duplicates.


* Compares the new list against the previous list to detect new additions and removed entries.


* Logs changes to the output file conditionally, controlled by the `LOG_CHANGES_TO_FILE` setting.


* Displays colorized console output for standard folders, recursed subfolders, warnings, and changes.


* Allows disabling ANSI colors by setting `NOANSI=1`.


* Supports an `IGNORE` list to completely skip specific folders.


* Supports a `RECURSE` list to treat specific folders as containers, listing all subfolders recursively while skipping the container itself.


* Supports a `RECURSE_SKIP` list to ignore items during recursion based on partial name matches.


* Validates `IGNORE` and `RECURSE` entries and displays red warnings and a summary box for missing directories.



## Installation & Usage

1. Place `MovieListGenerator.bat` in the root directory containing the folders you want to list. All paths are relative to the folder where the script lives.


2. Run the script by double-clicking it or executing it via the command prompt.
3. The generated list will be saved as `MovieList.md` in the same directory.



## Configuration

Configuration is handled by editing the text directly at the bottom of the `.bat` file.

### Lists

Add your target folders between the designated labels (`:__IGNORE_LIST__`, `:__RECURSE_LIST__`, `:__RECURSE_SKIP_LIST__`).

* Use one folder or name per line with exact spelling.


* Empty lines are ignored.


* Lines starting with `;` or `::` are treated as comments and ignored.


* An optional semicolon `;` at the end of a line is supported and will be stripped.


* `IGNORE` entries match against relative paths inside `RECURSE` folders.



### Options

Modify the `:__OPTIONS__` section at the end of the file to change script behavior.

* `LOG_CHANGES_TO_FILE=1`: Appends the "New Additions" and "Removed Entries" sections to the output markdown file.


* `LOG_CHANGES_TO_FILE=0`: Keeps the output file clean and only displays the changes in the console.



## License

MIT License
