---
layout:     post
title:      "Spiral Matrix"
summary:    "\"default\""
date:       2023-11-18 19:24:38
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

# Spiral Matrix

Given an m x n matrix, return all elements of the matrix in spiral order.



```
Example 1:


Input: matrix = [[1,2,3],[4,5,6],[7,8,9]]
Output: [1,2,3,6,9,8,7,4,5]
Example 2:


Input: matrix = [[1,2,3,4],[5,6,7,8],[9,10,11,12]]
Output: [1,2,3,4,8,12,11,10,9,5,6,7]


Constraints:

m == matrix.length
n == matrix[i].length
1 <= m, n <= 10
-100 <= matrix[i][j] <= 100
```

# Solution

```c++
class Solution {
  public:
  enum direction { right, down, left, up };
  vector<int> spiralOrder(vector<vector<int>>& matrix) {
    vector<int> ans;
    vector<pair<int, int>> myVec;
    set<pair<int, int>> mySet;
    int row = matrix.size();
    int col = matrix[0].size();
    int n = row * col;
    int i = 0, j = 0;
    int d = right;
    auto tmp = make_pair(0, 0);
    mySet.insert(tmp);
    myVec.push_back(tmp);
    while (myVec.size() < n) {
      if (d == right) {
        int val = j + 1;
        if (val < col && mySet.count(make_pair(i, val)) == 0) {
          auto item = make_pair(i, val);
          mySet.insert(item);
          myVec.push_back(item);
          j = val;
        } else {
          d = (d + 1) % 4;
        }
      } else if (d == down) {
        int val = i + 1;
        if (val < row && mySet.count(make_pair(val, j)) == 0) {
          auto item = make_pair(val, j);
          mySet.insert(item);
          myVec.push_back(item);
          i = val;
        } else {
          d = (d + 1) % 4;
        }
      } else if (d == left) {
        int val = j - 1;
        if (val >= 0 && mySet.count(make_pair(i, val)) == 0) {
          auto item = make_pair(i, val);
          mySet.insert(item);
          myVec.push_back(item);
          j = val;
        } else {
          d = (d + 1) % 4;
        }
      } else if (d == up) {
        int val = i - 1;
        if (val >= 0 && mySet.count(make_pair(val, j)) == 0) {
          auto item = make_pair(val, j);
          mySet.insert(item);
          myVec.push_back(item);
          i = val;
        } else {
          d = (d + 1) % 4;
        }
      }
    }
    for (auto item : myVec) {
      ans.push_back(matrix[item.first][item.second]);
    }
    return ans;
  }
};
```

