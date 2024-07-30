#!/bin/zsh

# Function to print usage
print_usage() {
  echo "Usage: $0 [file1] [file2] ... -- [tag1] [tag2] ..."
  echo "Use -- to separate file list from tag list"
}

# Ensure at least three arguments are passed (at least one file, --, and one tag)
if [ "$#" -lt 3 ]; then
  print_usage
  exit 1
fi

# Initialize arrays for files and tags
files=()
tags=()
parsing_files=true

# Parse arguments
for arg in "$@"; do
  if [[ "$arg" == "--" ]]; then
    parsing_files=false
    continue
  fi
  
  if $parsing_files; then
    files+=("$arg")
  else
    tags+=("$arg")
  fi
done

# Check if we have at least one file and one tag
if [ ${#files[@]} -eq 0 ] || [ ${#tags[@]} -eq 0 ]; then
  print_usage
  exit 1
fi

# Process each file
for file in "${files[@]}"; do
  echo "Working on file: $file"
  # Process the file
  awk -v tags="${(j:,:)tags}" '
    BEGIN {
      split(tags, tag_array, ",");
      frontmatterExists = 0;
      inFrontmatter = 0;
      content = "";
      tagsSection = "";
    }
    # Check if the file starts with frontmatter
    NR == 1 && /^---$/ {
      frontmatterExists = 1;
      inFrontmatter = 1;
      print $0;
      next;
    }
    # Process existing frontmatter
    inFrontmatter {
      if (/^tags:/) {
        tagsSection = $0 "\n";
        while (getline && /^  - /) {
          tagsSection = tagsSection $0 "\n";
        }
        for (i in tag_array) {
          if (tagsSection !~ tag_array[i]) {
            tagsSection = tagsSection "  - " tag_array[i] "\n";
          }
        }
        printf "%s", tagsSection;
        if ($0 !~ /^  - /) print $0;
      } else if (/^---$/) {
        inFrontmatter = 0;
        print $0;
      } else {
        print $0;
      }
      next;
    }
    # Collect content if not in frontmatter
    {
      content = content $0 "\n";
    }
    # Add new frontmatter if it doesnt exist, or print collected content
    END {
      if (!frontmatterExists) {
        print "---";
        print "tags:";
        for (i in tag_array) {
          print "  - " tag_array[i];
        }
        print "---";
      }
      printf "%s", content;
    }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  echo "File processed."
done