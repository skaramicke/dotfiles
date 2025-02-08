#!/bin/zsh

# This function prepends lines to files matching a given pattern.
#
# Usage:
#   prepend <pattern> <line1> <line2> ...
#
# Arguments:
#   pattern: The filename pattern to search for (e.g., "*.md").
#   line1, line2, ...: The lines to prepend to each matching file.
#
# Description:
#   The function searches for files in the current directory and its subdirectories
#   that match the given pattern. For each matching file, it creates a temporary file,
#   writes the specified lines to the temporary file, and then appends the original
#   content of the matching file. Finally, it replaces the original file with the
#   temporary file.
#
# Example:
#   prepend "*.txt" "First line" "Second line"
#   This will prepend "First line" and "Second line" to all .md files in the current
#   directory and its subdirectories.
function prepend() {
  local pattern=$1
  shift
  find . -type f -name "$pattern" -print0 | while IFS= read -r -d '' file; do
    # Create a temporary file for storing the new content
    {
      for line in "$@"; do
        echo "$line"
      done
      cat "$file"
    } >"$file.tmp" && mv "$file.tmp" "$file"
  done
}