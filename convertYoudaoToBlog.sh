#########################################################################
# File Name: convertYoudaoToBlog.sh
# Author: BillCong
# mail: cjcbill@gmail.com
# Created Time: 2024.01.25
#########################################################################
#!/bin/bash

echo "start pulling markdown files..."
YOUTDAO_PULL_PATH="$HOME/GitHubs/youdaonote-pull"
BLOG_REPOSITORY_PATH="$HOME/GitHubs/ProgrammerBill.github.io"
INPUT_MD_PATH="$BLOG_REPOSITORY_PATH/youdao_posts"
OUTPUT_BLOG_PATH="$BLOG_REPOSITORY_PATH/_posts/blog/"
ADD_YAML_HEADER_PY="$BLOG_REPOSITORY_PATH/addYamlHeader.py"
DATE=`date +%Y-%m-%d`

echo "pulling markdown files..."
python $YOUTDAO_PULL_PATH/pull.py

find $INPUT_MD_PATH -type f -name "*.md" | while read file; do
    echo "Processing $file"
    # 在这里处理每个文件
    title_name=$(basename "$file" .md)
    python $ADD_YAML_HEADER_PY $file --title $title_name --output $OUTPUT_BLOG_PATH/$DATE-$title_name.md
done

cd $BLOG_REPOSITORY_PATH
if git diff-index --quiet HEAD --; then
    echo "no change"
else
    echo "change"
    git add .
    git commit -m "add new blog by auto robot"
    git push origin master
fi
echo "finishied"
