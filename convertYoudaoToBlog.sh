#########################################################################
# File Name: test.sh
# Author: BillCong
# mail: cjcbill@gmail.com
# Created Time: 2024.01.25
#########################################################################
#!/bin/bash

echo "start pulling markdown files..."
YOUTDAO_PULL_PATH="/home/chenjuncong/GitHubs/youdaonote-pull"
INPUT_MD_PATH="/home/chenjuncong/GitHubs/ProgrammerBill.github.io/youdao_posts"
OUTPUT_BLOG_PATH="/home/chenjuncong/GitHubs/ProgrammerBill.github.io/_posts/blog/"
ADD_YAML_HEADER_PY="/home/chenjuncong/GitHubs/ProgrammerBill.github.io/addYamlHeader.py"
DATE=`date +%Y-%m-%d`

cd $YOUTDAO_PULL_PATH
#source myenv/bin/activate
python pull.py
echo "pulling markdown files..."

find $INPUT_MD_PATH -type f -name "*.md" | while read file; do
    echo "Processing $file"
    # 在这里处理每个文件
    title_name=$(basename "$file" .md)
    python $ADD_YAML_HEADER_PY $file --title $title_name --output $OUTPUT_BLOG_PATH/$DATE-$title_name.md
done

cd /home/chenjuncong/GitHubs/ProgrammerBill.github.io/
git add .
git commit -m "add new blog"
git push origin master
echo "finishied"
