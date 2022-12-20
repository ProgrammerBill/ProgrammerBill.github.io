#########################################################################
# File Name: newBlog.sh
# Author: bill
# mail: cjcbill@gmail.com
# Created Time: 2019年07月04日 星期四 15时51分29秒
#########################################################################
#!/bin/bash

title=$1
current_date=`date +%Y-%m-%d`
current_time=`date +%H:%M:%S`

cat > ${current_date}-${title}.md << EOF
---
layout:     post
title:      "default"
subtitle:    "default"
date:       $current_date $current_time
author:     "Bill"
header-img: "img/bill/header-posts/$current_date-header.jpg"
catalog: true
tags:
    - default
---
EOF
