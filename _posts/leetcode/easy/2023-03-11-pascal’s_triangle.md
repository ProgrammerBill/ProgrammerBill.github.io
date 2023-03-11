---
layout:     post
title:      "Pascal’s Triangle"
summary:    "\"杨辉三角\""
date:       2023-03-11 13:39:05
author:     "Bill"
header-img: "img/bill/header-posts/2023-03-11-header.jpg"
catalog: true
stickie: false
hide: true
life: false
guitartab: false
tags:
    - default
---

# Pascal’s Triangle

Given an integer numRows, return the first numRows of Pascal's triangle.

In Pascal's triangle, each number is the sum of the two numbers directly above it as shown:

Example 1:

Input: numRows = 5
Output: [[1],[1,1],[1,2,1],[1,3,3,1],[1,4,6,4,1]]

Example 2:

Input: numRows = 1
Output: [[1]]

## C++ Solution

```c++
    vector<vector<int>> generate(int numRows) {
        vector<vector<int>>  triangles;
        vector<int> lastRow;
        for (int i = 0; i < numRows; i++) {
            vector<int> row;
            if (i == 0) {
                row.push_back(1);
            }
            int curRowNum = i + 1;
            int j = 0;
            if (!lastRow.empty()) {
                while (j < curRowNum - 1) {
                    int left = 0;
                    if (j - 1 < 0) {
                        left = 0;
                    } else {
                        left = lastRow[j - 1];
                    }
                    row.push_back(lastRow[j] + left);
                    j++;
                }
                row.push_back(1);
            }
            triangles.push_back(row);
            lastRow = row;
        }
        return triangles;
    }
```

