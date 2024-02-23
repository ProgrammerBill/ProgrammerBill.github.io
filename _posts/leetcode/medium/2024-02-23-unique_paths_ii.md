---
layout:     post
title:      "Unique Paths II"
summary:    "\"default\""
date:       2024-02-23 11:13:00
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

# Unique Paths II

You are given an m x n integer array grid. There is a robot initially located at the top-left corner (i.e., grid[0][0]). The robot tries to move to the bottom-right corner (i.e., grid[m - 1][n - 1]). The robot can only move either down or right at any point in time.

An obstacle and space are marked as 1 or 0 respectively in grid. A path that the robot takes cannot include any square that is an obstacle.

Return the number of possible unique paths that the robot can take to reach the bottom-right corner.

The testcases are generated so that the answer will be less than or equal to 2 * 109.

```
Example 1:


Input: obstacleGrid = [[0,0,0],[0,1,0],[0,0,0]]
Output: 2
Explanation: There is one obstacle in the middle of the 3x3 grid above.
There are two ways to reach the bottom-right corner:
1. Right -> Right -> Down -> Down
2. Down -> Down -> Right -> Right
Example 2:


Input: obstacleGrid = [[0,1],[0,0]]
Output: 1


Constraints:

m == obstacleGrid.length
n == obstacleGrid[i].length
1 <= m, n <= 100
obstacleGrid[i][j] is 0 or 1.
```

# Solution

```c++
class Solution {
  public:
  int uniquePathsWithObstacles(vector<vector<int>>& obstacleGrid) {
    int m = obstacleGrid.size();
    int n = obstacleGrid[0].size();
    int dicts[m][n];
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < n; j++) {
        dicts[i][j] = 0;
      }
    }
    for (int i = 0; i < m; i++) {
      if (obstacleGrid[i][0] == 1) {
        break;
      }
      dicts[i][0] = 1;
    }
    for (int i = 0; i < n; i++) {
      if (obstacleGrid[0][i] == 1) {
        break;
      }
      dicts[0][i] = 1;
    }
    for (int i = 1; i < m; i++) {
      for (int j = 1; j < n; j++) {
        if (dicts[i][j] == 0 && obstacleGrid[i][j] == 0) {
          dicts[i][j] = (obstacleGrid[i - 1][j] == 0 ? dicts[i - 1][j] : 0) +
                        (obstacleGrid[i][j - 1] == 0 ? dicts[i][j - 1] : 0);
        }
      }
    }
    return dicts[m - 1][n - 1];
  }
};
```
