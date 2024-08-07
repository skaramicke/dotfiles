#!/bin/zsh

# Reset test environment
# if test directory does not exist, create it
if [ ! -d ./test ]; then
  mkdir ./test
fi
rm ./test/*.md
cp ./test_source/*.md ./test/

# Print the code
echo "# add_md_tag.sh"
echo "\`\`\`"
cat ./scripts/add_md_tag.sh
echo "\`\`\`"
echo ""

# Print the test code
echo "# test_md_tags.sh"
echo "\`\`\`"
cat ./test_md_tags.sh
echo "\`\`\`"
echo ""

# For each file in the test directory, print the file name and the contents of the file
echo "# Before"
for file in ./test/*.md; do
  echo "$file:"
  echo "\`\`\`"
  cat "$file"
  echo "\`\`\`"
  echo ""
done

./scripts/add_md_tag.sh ./test/*.md -- test1 test2

echo "# After"
for file in ./test/*.md; do
  echo "$file"
  echo "\`\`\`"
  cat "$file"
  echo "\`\`\`"
  echo ""
done
