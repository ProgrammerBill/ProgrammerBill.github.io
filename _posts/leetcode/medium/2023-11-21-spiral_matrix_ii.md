---
layout:     post
title:      "Spiral Matrix II"
summary:    "\"default\""
date:       2023-11-21 10:59:22
author:     "Bill"
header-img: "img/bill/header-posts/2023-033-11-header.jpg"
catalog: true
stickie: false
hide: true
life: false
guitartab: false
tags:
    - default
---

# Spiral Matrix II


Given a positive integer n, generate an n x n matrix filled with elements from 1 to n2 in spiral order.



```
Example 1:


Input: n = 3
Output: [[1,2,3],[8,9,4],[7,6,5]]
Example 2:

Input: n = 1
Output: [[1]]


Constraints:

1 <= n <= 20
```

# Solution

```
class Solution {
  public:
  enum direction { right, down, left, up };
  vector<vector<int>> generateMatrix(int n) {
    vector<vector<int>> ans(n, vector<int>(n, 0));
    int d = right;
    int row = 0;
    int col = 0;
    ans[0][0] = 1;
    for (int i = 2; i <= (n * n); i++) {
      if (d == right) {
        int val = col + 1;
        if (val < n && ans[row][val] == 0) {
          ans[row][val] = i;
          col = val;
        } else {
          d = down;
          i--;
        }
      } else if (d == down) {
        int val = row + 1;
        if (val < n && ans[val][col] == 0) {
          ans[val][col] = i;
          row = val;
        } else {
          d = left;
          i--;
        }
      } else if (d == left) {
        int val = col - 1;
        if (val >= 0 && ans[row][val] == 0) {
          ans[row][val] = i;
          col = val;
        } else {
          d = up;
          i--;
        }
      } else if (d == up) {
        int val = row - 1;
        if (val >= 0 && ans[val][col] == 0) {
          ans[val][col] = i;
          row = val;
        } else {
          d = right;
          i--;
        }
      }
    }
    return ans;
  }
};
```
