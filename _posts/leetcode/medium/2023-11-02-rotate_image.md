---
layout:     post
title:      "Rotate Image"
summary:    "\"default\""
date:       2023-11-02 14:47:17
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

# Rotate Image

You are given an n x n 2D matrix representing an image, rotate the image by 90 degrees (clockwise).

You have to rotate the image in-place, which means you have to modify the input 2D matrix directly. DO NOT allocate another 2D matrix and do the rotation.


```
Example 1:
Input: matrix = [[1,2,3],[4,5,6],[7,8,9]]
Output: [[7,4,1],[8,5,2],[9,6,3]]

Example 2:
Input: matrix = [[5,1,9,11],[2,4,8,10],[13,3,6,7],[15,14,12,16]]
Output: [[15,13,2,5],[14,3,4,1],[12,6,8,9],[16,7,10,11]]
```

# Solution


```c++
class Solution {
  public:
    void rotate(vector<vector<int>>& matrix) {
      int n = matrix.size();
      for (int i = 0; i < n / 2; ++i) {
        for (int j = 0; j < (n + 1) / 2; ++j) {
          int temp = matrix[i][j];
          matrix[i][j] = matrix[n - j - 1][i];
          matrix[n - j - 1][i] = matrix[n - i - 1][n - j - 1];
          matrix[n - i - 1][n - j - 1] = matrix[j][n - i - 1];
          matrix[j][n - i - 1] = temp;
        }
      }
    }
};
```
