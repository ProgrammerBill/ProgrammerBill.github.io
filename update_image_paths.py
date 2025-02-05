import sys
import re

def update_image_paths(md_file):
    with open(md_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # 替换图片路径
    updated_content = re.sub(r'(!\[.*?\]\()images/', r'\1img/bill/in-posts/images/', content)

    # 覆盖写回 Markdown 文件
    with open(md_file, 'w', encoding='utf-8') as f:
        f.write(updated_content)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python update_image_paths.py <markdown_file>")
        sys.exit(1)

    md_file = sys.argv[1]
    update_image_paths(md_file)
