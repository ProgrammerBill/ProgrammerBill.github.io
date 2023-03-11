---
layout:     post
title:      "Pascal’s Triangle II"
summary:    "\"杨辉三角 II\""
date:       2023-03-11 13:41:57
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

# Pascal’s Triangle II

Given an integer rowIndex, return the rowIndexth (0-indexed) row of the Pascal's triangle.

In Pascal's triangle, each number is the sum of the two numbers directly above it as shown:

Example 1:

Input: rowIndex = 3
Output: [1,3,3,1]
Example 2:

Input: rowIndex = 0
Output: [1]
Example 3:

Input: rowIndex = 1
Output: [1,1]


## C++ Solution

```c++
vector<int> getRow(int rowIndex) {
  vector<int> lastRow;
  vector<int> row;
  for (int i = 0; i < rowIndex + 1; i++) {
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
    lastRow = row;
    row.clear();
  }
  return lastRow;
}
```


