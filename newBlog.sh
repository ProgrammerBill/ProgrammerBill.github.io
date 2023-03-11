#########################################################################
# File Name: newBlog.sh
# Author: bill
# mail: cjcbill@gmail.com
# Created Time: 2019年07月04日 星期四 15时51分29秒
#########################################################################
#!/bin/bash


current_date=`date +%Y-%m-%d`
current_time=`date +%H:%M:%S`

usage() {
cat << EOF
    usage: $0 -t <"title name"> -s <"summary"> [-h] [-g] [-a] [-l]
    -t: Add Blog's title
    -s: Add Summary content
    -g: tag as a guitartab Blog, default is Technical Blog.
    -l: tag as a life Blog, default is Technical Blog.
    -a: add stickie to keep blog as top.
    -b: hide blog as default
    -h: show usage
EOF
}

title="default"
lower_title="default"
summary="default"
hide_blog="false"
is_life="false"
is_guitartab="false"
is_stickie="false"
while getopts "l:t:s:hgab" o; do
    case "${o}" in
        t)
            title=${OPTARG}
            lower_title=$(echo "$title" | tr '[:upper:]' '[:lower:]')
            lower_title="${lower_title// /_}"
            ;;
        l)
            is_life="true"
            ;;
        s)
            summary=${OPTARG}
            ;;
        g)
            is_guitartab="true"
            ;;
        a)
            is_stickie="true"
            ;;
        b)
            hide_blog="true"
            ;;
        h)
            usage && exit
            ;;
    esac
done
shift $((OPTIND-1))

cat > ${current_date}-${lower_title}.md << EOF
---
layout:     post
title:      "$title"
summary:    "\"$summary\""
date:       $current_date $current_time
author:     "Bill"
header-img: "img/bill/header-posts/$current_date-header.jpg"
catalog: true
stickie: $is_stickie
hide: $hide_blog
life: $is_life
guitartab: $is_guitartab
tags:
    - default
---
EOF
