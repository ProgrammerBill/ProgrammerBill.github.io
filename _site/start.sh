#########################################################################
# File Name: start.sh
# Author: bill
# mail: cjcbill@gmail.com
# Created Time: Sat Oct 13 11:23:57 2018
#########################################################################
#!/bin/bash

nohup jekyll serve --port 4000 --watch >/dev/null 2>&1 &
