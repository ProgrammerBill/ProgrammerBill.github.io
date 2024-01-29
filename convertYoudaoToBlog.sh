#########################################################################
# File Name: convertYoudaoToBlog.sh
# Author: BillCong
# mail: cjcbill@gmail.com
# Created Time: 2024.01.25
#########################################################################
#!/bin/bash
set -x
echo "start pulling markdown files..."
YOUTDAO_PULL_PATH="$HOME/GitHubs/youdaonote-pull"
BLOG_REPOSITORY_PATH="$HOME/GitHubs/ProgrammerBill.github.io"
INPUT_MD_PATH="$BLOG_REPOSITORY_PATH/youdao_posts"
OUTPUT_BLOG_PATH="$BLOG_REPOSITORY_PATH/_posts/"
ADD_YAML_HEADER_PY="$BLOG_REPOSITORY_PATH/addYamlHeader.py"
DATE=`date +%Y-%m-%d`
INPUT_DIR=("blog" "plan")

echo "pulling markdown files..."
cd $YOUTDAO_PULL_PATH
python pull.py

# blog
find $INPUT_MD_PATH/${INPUT_DIR[0]} -type f -name "*.md" | while read file; do
    echo "Processing $file"
    # 在这里处理每个文件
    title_name=$(basename "$file" .md)
    result=$(find $OUTPUT_BLOG_PATH/${INPUT_DIR[0]} -type f -name "*$title_name*")
    output_name="$DATE-$title_name.md"
    # 检查变量内容
    if [ -z "$result" ]; then
        echo "没有找到匹配的文件，正在创建新文件..."
    else
        echo "找到了匹配的文件："
        echo "$result"
        output_name=$(basename "$result")
    fi
    python $ADD_YAML_HEADER_PY "$file" --title "$title_name" --summary "$title_name" --output "$OUTPUT_BLOG_PATH/${INPUT_DIR[0]}/${output_name}"
    rm "$file"
done

# plan
find $INPUT_MD_PATH/${INPUT_DIR[1]} -type f -name "*.md" | while read file; do
    echo "Processing $file"
    title_name=$(basename "$file" .md)
    result=$(find $OUTPUT_BLOG_PATH/${INPUT_DIR[1]} -type f -name "*$title_name*")
    output_name="$DATE-$title_name.md"
    # 检查变量内容
    if [ -z "$result" ]; then
        echo "没有找到匹配的文件，正在创建新文件..."
    else
        echo "找到了匹配的文件："
        echo "$result"
        output_name=$(basename "$result")
    fi
    python $ADD_YAML_HEADER_PY "$file" --title "$title_name" --summary "$title_name" --date $DATE --stickie --output "$OUTPUT_BLOG_PATH/${INPUT_DIR[1]}/$DATE-$title_name.md"
    rm "$file"
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
set +x
