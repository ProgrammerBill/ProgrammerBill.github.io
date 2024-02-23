---
layout:     post
title:      "Unique Paths"
summary:    "\"default\""
date:       2024-02-23 10:00:15
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

# Unique Paths

There is a robot on an m x n grid. The robot is initially located at the top-left corner (i.e., grid[0][0]). The robot tries to move to the bottom-right corner (i.e., grid[m - 1][n - 1]). The robot can only move either down or right at any point in time.

Given the two integers m and n, return the number of possible unique paths that the robot can take to reach the bottom-right corner.

The test cases are generated so that the answer will be less than or equal to 2 * 109.

```
Example 1:

Input: m = 3, n = 7
Output: 28

Example 2:

Input: m = 3, n = 2
Output: 3

Explanation: From the top-left corner, there are a total of 3 ways to reach the bottom-right corner:
1. Right -> Down -> Down
2. Down -> Down -> Right
3. Down -> Right -> Down
```

# Solution

```c++
class Solution {
  public:
  int uniquePaths(int m, int n) {
    int dicts[m][n];
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        dicts[i][j] = 0;
      }
    }
    for (int i = 0; i < m; i++) {
      dicts[i][0] = 1;
    }
    for (int i = 0; i < n; i++) {
      dicts[0][i] = 1;
    }
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        if (dicts[i][j] == 0) {
          dicts[i][j] = dicts[i - 1][j] + dicts[i][j - 1];
        }
      }
    }
    return dicts[m - 1][n - 1];
  }
};
```
