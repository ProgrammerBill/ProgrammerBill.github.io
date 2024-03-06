---
layout:     post
title:      "Minimum Path Sum"
summary:    "\"default\""
date:       2024-03-06 14:19:02
author:     "Bill"
header-img: "img/bill/header-posts/2024-03-06-header.jpg"
catalog: true
stickie: false
hide: true
life: false
guitartab: false
tags:
    - default
---


# 64. Minimum Path Sum

Given a m x n grid filled with non-negative numbers, find a path from top left to bottom right, which minimizes the sum of all numbers along its path.

Note: You can only move either down or right at any point in time.

```

Example 1:


Input: grid = [[1,3,1],[1,5,1],[4,2,1]]
Output: 7
Explanation: Because the path 1 → 3 → 1 → 1 → 1 minimizes the sum.
Example 2:

Input: grid = [[1,2,3],[4,5,6]]
Output: 12
```

# Solution

```c++
class Solution {
  public:
  int minPathSum(vector<vector<int>>& grid) {
    int rows = grid.size();
    int cols = grid[0].size();
    vector<vector<int>> results(rows, vector<int>(cols, 0));
    results[0][0] = grid[0][0];
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        if (i > 0 && j > 0) {
          results[i][j] = std::min(results[i - 1][j], results[i][j - 1]) + grid[i][j];
        } else if (i > 0 && j == 0) {
          results[i][j] = results[i - 1][j] + grid[i][j];
        } else if (i == 0 && j > 0) {
          results[i][j] += results[i][j - 1] + grid[i][j];
        }
      }
    }
    return results[rows - 1][cols - 1];
  }
};
```
