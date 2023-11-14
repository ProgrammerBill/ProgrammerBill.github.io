---
layout:     post
title:      "N-Queens II"
summary:    "\"default\""
date:       2023-11-14 09:27:51
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

# N-Queens II


The n-queens puzzle is the problem of placing n queens on an n x n chessboard such that no two queens attack each other.

Given an integer n, return the number of distinct solutions to the n-queens puzzle.



```
Example 1:


Input: n = 4
Output: 2
Explanation: There are two distinct solutions to the 4-queens puzzle as shown.
Example 2:

Input: n = 1
Output: 1


Constraints:

1 <= n <= 9
```

# Solution

```c++
class Solution {
  private:
  vector<vector<string>> res;
  unordered_set<int> colSet;
  unordered_set<int> diag1Set;
  unordered_set<int> diag2Set;

  public:
  bool checkVec(int row, int col) {
    // Check column conflicts
    if (colSet.count(col) > 0) {
      return false;
    }

    // Check diagonal conflicts
    if (diag1Set.count(row + col) > 0 || diag2Set.count(row - col) > 0) {
      return false;
    }
    return true;
  }
  void solveNQueensImpl(int row, int n, vector<int> board) {
    if (row == n) {
      vector<string> tmpVec;
      for (int i = 0; i < n; i++) {
        string tmp(n, '.');
        tmp[board[i]] = 'Q';
        tmpVec.push_back(tmp);
      }
      res.push_back(tmpVec);
      return;
    }

    for (int col = 0; col < n; col++) {
      if (checkVec(row, col)) {
        board[row] = col;
        colSet.insert(col);
        diag1Set.insert(row + col);
        diag2Set.insert(row - col);

        solveNQueensImpl(row + 1, n, board);

        colSet.erase(col);
        diag1Set.erase(row + col);
        diag2Set.erase(row - col);
      }
    }
  }
  vector<vector<string>> solveNQueens(int n) {
    vector<int> board(n, 0);
    solveNQueensImpl(0, n, board);
    return res;
  }
  int totalNQueens(int n) {
    return solveNQueens(n).size();  
  }
};
```



