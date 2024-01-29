#!/usr/bin/python
# -*- coding: utf-8 -*-

import argparse
import yaml

# 设置命令行参数
parser = argparse.ArgumentParser(description="Add a YAML header to a file.")
parser.add_argument("file", help="Path to the input file")
parser.add_argument("--title", help="Title for the YAML header", default="Default Title")
parser.add_argument("--summary", help="summary for the YAML header", default="Default Summary")
parser.add_argument("--author", help="Author for the YAML header", default="Bill")
parser.add_argument("--header-img", help="image for the YAML header", default="img/bill/header-posts/2024-01-24-header.png")
parser.add_argument("--date", help="Date for the YAML header", default="2024-01-25")
parser.add_argument("--catalog", help="set catalog for blog", default=True)
parser.add_argument("--stickie", action='store_true', help="set this blog to the top", default=False)
parser.add_argument("--hide", help="hide this blog?", default=False)
parser.add_argument("--life", help="this blog is for life not tech?", default=False)
parser.add_argument("--guitartab", help="this blog is for guitartab?", default=False)
parser.add_argument("--tags", help="Comma-separated tags for the YAML header", default="")
parser.add_argument("--output", help="Path to the output file", default=None)

# 解析命令行参数
args = parser.parse_args()

# 分割tags字符串成列表
tags_list = args.tags.split(',') if args.tags else []

# 定义YAML header
yaml_header = {
    'layout': 'post',
    'title': args.title,
    'summary': args.summary,
    'date': args.date,
    'author': args.author,
    'header-img': args.header_img,
    'catalog': args.catalog,
    'stickie': args.stickie,
    'hide': args.hide,
    'life': args.life,
    'guitartab': args.guitartab,
    'tags': tags_list
}

yaml_header_str = '---\n' + yaml.dump(yaml_header, allow_unicode=True) + '---\n'

# 读取原始文件内容
with open(args.file, 'r') as file:
    original_content = file.read()

# 合并YAML header和原始内容
new_content = yaml_header_str + original_content

# 输出文件路径
output_path = args.output if args.output else args.file

# 将新内容写入文件
with open(output_path, 'w') as file:
    file.write(new_content)

print(f"YAML header added successfully. Output file: {output_path}")
