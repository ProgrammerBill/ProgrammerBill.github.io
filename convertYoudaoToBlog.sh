#########################################################################
# File Name: convertYoudaoToBlog.sh
# Author: BillCong
# mail: cjcbill@gmail.com
# Created Time: 2024.01.25
#########################################################################
#!/bin/bash

echo "start pulling markdown files..."
YOUTDAO_PULL_PATH="$HOME/GitHubs/youdaonote-pull"
INPUT_MD_PATH="$HOME/GitHubs/ProgrammerBill.github.io/youdao_posts"
OUTPUT_BLOG_PATH="$HOME/GitHubs/ProgrammerBill.github.io/_posts/blog/"
ADD_YAML_HEADER_PY="$HOME/GitHubs/ProgrammerBill.github.io/addYamlHeader.py"
DATE=`date +%Y-%m-%d`

cd $YOUTDAO_PULL_PATH
python pull.py
echo "pulling markdown files..."

find $INPUT_MD_PATH -type f -name "*.md" | while read file; do
    echo "Processing $file"
    # 在这里处理每个文件
    title_name=$(basename "$file" .md)
    python $ADD_YAML_HEADER_PY $file --title $title_name --output $OUTPUT_BLOG_PATH/$DATE-$title_name.md
done

cd $HOME/GitHubs/ProgrammerBill.github.io/
if git diff-index --quiet HEAD --; then
    echo "no change"
else
    echo "change"
    git add .
    git commit -m "add new blog by auto robot"
    git push origin master
fi
echo "finishied"
