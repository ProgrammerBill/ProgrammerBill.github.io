---
layout:     post
title:      "Valid Sudoku"
summary:    "\"default\""
date:       2023-10-07 10:30:16
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


# 36. Valid Sudoku

Determine if a 9 x 9 Sudoku board is valid. Only the filled cells need to be validated according to the following rules:

Each row must contain the digits 1-9 without repetition.
Each column must contain the digits 1-9 without repetition.
Each of the nine 3 x 3 sub-boxes of the grid must contain the digits 1-9 without repetition.
Note:

A Sudoku board (partially filled) could be valid but is not necessarily solvable.
Only the filled cells need to be validated according to the mentioned rules.

```
Example 1:


Input: board =
[["5","3",".",".","7",".",".",".","."]
,["6",".",".","1","9","5",".",".","."]
,[".","9","8",".",".",".",".","6","."]
,["8",".",".",".","6",".",".",".","3"]
,["4",".",".","8",".","3",".",".","1"]
,["7",".",".",".","2",".",".",".","6"]
,[".","6",".",".",".",".","2","8","."]
,[".",".",".","4","1","9",".",".","5"]
,[".",".",".",".","8",".",".","7","9"]]
Output: true
Example 2:

Input: board =
[["8","3",".",".","7",".",".",".","."]
,["6",".",".","1","9","5",".",".","."]
,[".","9","8",".",".",".",".","6","."]
,["8",".",".",".","6",".",".",".","3"]
,["4",".",".","8",".","3",".",".","1"]
,["7",".",".",".","2",".",".",".","6"]
,[".","6",".",".",".",".","2","8","."]
,[".",".",".","4","1","9",".",".","5"]
,[".",".",".",".","8",".",".","7","9"]]
Output: false
Explanation: Same as Example 1, except with the 5 in the top left corner being modified to 8. Since there are two 8's in the top left 3x3 sub-box, it is invalid.

Constraints:

board.length == 9
board[i].length == 9
board[i][j] is a digit 1-9 or '.'.
```


# Solution

```c++

bool isValidNums(const vector<char>& input) {
  int len = input.size();
  set<char> tmp;
  for (auto item : input) {
    tmp.insert(item);
  }
  return len == tmp.size();
}
bool isValidSudoku(vector<vector<char>>& board) {
  int rowLen = board.size();
  int colLen = board[0].size();
  for (int i = 0; i < rowLen; i++) {
    vector<char> tmp;
    for (int j = 0; j < colLen; j++) {
      if (isdigit(board[i][j])) {
        tmp.push_back(board[i][j]);
      }
    }
    if (!isValidNums(tmp)) {
      return false;
    }
  }
  for (int i = 0; i < colLen; i++) {
    vector<char> tmp;
    for (int j = 0; j < rowLen; j++) {
      if (isdigit(board[j][i])) {
        tmp.push_back(board[j][i]);
      }
    }
    if (!isValidNums(tmp)) {
      return false;
    }
  }

  for (int i = 0; i < rowLen; i += 3) {
    for (int j = 0; j < colLen; j += 3) {
      vector<char> tmp;
      for (int x = 0; x < 3; x++) {
        for (int y = 0; y < 3; y++) {
          if (isdigit(board[i + x][j + y])) {
            tmp.push_back(board[i + x][j + y]);
          }
        }
      }
      if (!isValidNums(tmp)) {
        return false;
      }
    }
  }

  return true;
}
```

