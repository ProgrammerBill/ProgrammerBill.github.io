#########################################################################
# File Name: convertYoudaoToBlog.sh
# Author: BillCong
# mail: cjcbill@gmail.com
# Created Time: 2024.01.25
#########################################################################
#!/bin/bash
#set -x
echo "start pulling markdown files..."
YOUTDAO_PULL_PATH="$HOME/GitHubs/youdaonote-pull"
BLOG_REPOSITORY_PATH="$HOME/GitHubs/ProgrammerBill.github.io"
INPUT_MD_PATH="$BLOG_REPOSITORY_PATH/youdao_posts"
OUTPUT_BLOG_PATH="$BLOG_REPOSITORY_PATH/_posts/"
ADD_YAML_HEADER_PY="$BLOG_REPOSITORY_PATH/addYamlHeader.py"
UPDATE_IMAGE_PATHS_PY="$BLOG_REPOSITORY_PATH/update_image_paths.py"
INPUT_DIR=("blog" "plan" "life")

echo "pulling markdown files..."
cd $YOUTDAO_PULL_PATH
python pull.py

# blog
find $INPUT_MD_PATH/${INPUT_DIR[0]} -type f -name "*.md" | while read file; do
    echo "Processing $file"
    # 更新 Markdown 文件中的图片路径
    python $UPDATE_IMAGE_PATHS_PY "$file"
    # 在这里处理每个文件
    title_name=$(basename "$file" .md)
    result=$(find $OUTPUT_BLOG_PATH/${INPUT_DIR[0]} -type f -name "*$title_name*")
    DATE=`date +%Y-%m-%d`
    output_name="$DATE-$title_name.md"
    # 检查变量内容
    if [ -z "$result" ]; then
        echo "没有找到匹配的文件，正在创建新文件..."
    else
        echo "找到了匹配的文件："
        echo "$result"
        output_name=$(basename "$result")
        DATE=$(echo $output_name | cut -d'-' -f1-3)
    fi
    python $ADD_YAML_HEADER_PY "$file" --title "$title_name" --summary "$title_name" --date $DATE --output "$OUTPUT_BLOG_PATH/${INPUT_DIR[0]}/${output_name}"
    rm "$file"
done

if [ -d "${INPUT_MD_PATH}/${INPUT_DIR[0]}"/images ]; then
    echo "img/bill/in-posts exists"
    cp -rf "${INPUT_MD_PATH}/${INPUT_DIR[0]}"/images "$BLOG_REPOSITORY_PATH/img/bill/in-posts/"
fi

# plan
find $INPUT_MD_PATH/${INPUT_DIR[1]} -type f -name "*.md" | while read file; do
    echo "Processing $file"
    # 更新 Markdown 文件中的图片路径
    python $UPDATE_IMAGE_PATHS_PY "$file"
    title_name=$(basename "$file" .md)
    result=$(find $OUTPUT_BLOG_PATH/${INPUT_DIR[1]} -type f -name "*$title_name*")
    DATE=`date +%Y-%m-%d`
    output_name="$DATE-$title_name.md"
    # 检查变量内容
    if [ -z "$result" ]; then
        echo "没有找到匹配的文件，正在创建新文件..."
    else
        echo "找到了匹配的文件："
        echo "$result"
        output_name=$(basename "$result")
        DATE=$(echo $output_name | cut -d'-' -f1-3)
    fi
    python $ADD_YAML_HEADER_PY "$file" --title "$title_name" --summary "$title_name" --date $DATE --stickie --output "$OUTPUT_BLOG_PATH/${INPUT_DIR[1]}/${output_name}"
    rm "$file"
done

if [ -d "${INPUT_MD_PATH}/${INPUT_DIR[1]}"/images ]; then
    echo "img/bill/in-posts exists"
    cp -rf "${INPUT_MD_PATH}/${INPUT_DIR[1]}"/images "$BLOG_REPOSITORY_PATH/img/bill/in-posts/"
fi


# life
find $INPUT_MD_PATH/${INPUT_DIR[2]} -type f -name "*.md" | while read file; do
    echo "Processing $file"
    # 更新 Markdown 文件中的图片路径
    python $UPDATE_IMAGE_PATHS_PY "$file"
    title_name=$(basename "$file" .md)
    result=$(find $OUTPUT_BLOG_PATH/${INPUT_DIR[2]} -type f -name "*$title_name*")
    DATE=`date +%Y-%m-%d`
    output_name="$DATE-$title_name.md"
    # 检查变量内容
    if [ -z "$result" ]; then
        echo "没有找到匹配的文件，正在创建新文件..."
    else
        echo "找到了匹配的文件："
        echo "$result"
        output_name=$(basename "$result")
        DATE=$(echo $output_name | cut -d'-' -f1-3)
    fi
    python $ADD_YAML_HEADER_PY "$file" --title "$title_name" --summary "$title_name" --date $DATE --stickie --life --output "$OUTPUT_BLOG_PATH/${INPUT_DIR[2]}/${output_name}"
    rm "$file"
done

if [ -d "${INPUT_MD_PATH}/${INPUT_DIR[2]}"/images ]; then
    echo "img/bill/in-posts exists"
    cp -rf "${INPUT_MD_PATH}/${INPUT_DIR[2]}"/images "$BLOG_REPOSITORY_PATH/img/bill/in-posts/"
fi

cd $BLOG_REPOSITORY_PATH
if git diff-index --quiet HEAD --; then
    echo "no change"
else
    echo "change"
    git pull
    git add .
    git commit -m "add new blog by auto robot"
    git push origin master
fi
echo "finishied"
#set +x
