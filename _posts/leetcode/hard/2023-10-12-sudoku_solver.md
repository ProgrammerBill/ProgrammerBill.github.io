---
layout:     post
title:      "Sudoku Solver"
summary:    "\"default\""
date:       2023-10-12 14:37:20
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



# 37. Sudoku Solver

Write a program to solve a Sudoku puzzle by filling the empty cells.

A sudoku solution must satisfy all of the following rules:

Each of the digits 1-9 must occur exactly once in each row.
Each of the digits 1-9 must occur exactly once in each column.
Each of the digits 1-9 must occur exactly once in each of the 9 3x3 sub-boxes of the grid.
The '.' character indicates empty cells.


```
Example 1:


Input: board = [["5","3",".",".","7",".",".",".","."],["6",".",".","1","9","5",".",".","."],[".","9","8",".",".",".",".","6","."],["8",".",".",".","6",".",".",".","3"],["4",".",".","8",".","3",".",".","1"],["7",".",".",".","2",".",".",".","6"],[".","6",".",".",".",".","2","8","."],[".",".",".","4","1","9",".",".","5"],[".",".",".",".","8",".",".","7","9"]]
Output: [["5","3","4","6","7","8","9","1","2"],["6","7","2","1","9","5","3","4","8"],["1","9","8","3","4","2","5","6","7"],["8","5","9","7","6","1","4","2","3"],["4","2","6","8","5","3","7","9","1"],["7","1","3","9","2","4","8","5","6"],["9","6","1","5","3","7","2","8","4"],["2","8","7","4","1","9","6","3","5"],["3","4","5","2","8","6","1","7","9"]]
Explanation: The input board is shown above and the only valid solution is shown below:

```

# solution

```c++
class Solution {
  private:
  bool valid;
  int rowsGotDigit[9][9] = {0};
  int colGotDigit[9][9] = {0};
  int blockGotDigit[9][9] = {0};
  vector<pair<int, int>> dots;

  public:
  void debug(int (*head)[9], int rowSize, int colSize) {
    for (int i = 0; i < rowSize; i++) {
      for (int j = 0; j < colSize; j++) {
        cout << head[i][j] << " ";
      }
      cout << endl;
    }
  }
  void printBoard(vector<vector<char>>& board) {
    for (auto row : board) {
      for (auto item : row) {
        cout << item << " ";
      }
      cout << endl;
    }
  }

  void dfs(vector<vector<char>>& board, int pos) {
    if (pos == dots.size()) {
      valid = true;
      return;
    }
    auto item = dots[pos];
    int x = item.first;
    int y = item.second;
    for (int i = 0; i < 9 && !(valid); i++) {
      if (rowsGotDigit[x][i] == 0 && colGotDigit[y][i] == 0 &&
          blockGotDigit[(x / 3 * 3) + (y / 3)][i] == 0) {
        board[x][y] = '0' + i + 1;
        rowsGotDigit[x][i] = colGotDigit[y][i] =
            blockGotDigit[(x / 3 * 3) + (y / 3)][i] = 1;
        dfs(board, pos + 1);
        rowsGotDigit[x][i] = colGotDigit[y][i] =
            blockGotDigit[(x / 3 * 3) + (y / 3)][i] = 0;
      }
    }
  }

  void solveSudoku(vector<vector<char>>& board) {
    int rowSize = board.size();
    int colSize = board[0].size();
    for (int i = 0; i < rowSize; i++) {
      for (int j = 0; j < colSize; j++) {
        char item = board[i][j];
        if (item != '.') {
          int num = item - '0';
          rowsGotDigit[i][num - 1] = 1;
        } else {
          dots.push_back(make_pair(i, j));
        }
      }
    }
    //debug(rowsGotDigit, rowSize, colSize);
    for (int j = 0; j < colSize; j++) {
      for (int i = 0; i < rowSize; i++) {
        char item = board[j][i];
        if (item != '.') {
          int num = item - '0';
          colGotDigit[i][num - 1] = 1;
        }
      }
    }
    //debug(colGotDigit, rowSize, colSize);
    for (int i = 0; i < rowSize; i += 3) {
      for (int j = 0; j < colSize; j += 3) {
        for (int x = 0; x < 3; x++) {
          for (int y = 0; y < 3; y++) {
            char item = board[i + x][j + y];
            if (item != '.') {
              int num = item - '0';
              blockGotDigit[i + (j / 3)][num - 1] = 1;
            }
          }
        }
      }
    }
    //debug(blockGotDigit, rowSize, colSize);
    valid = false;
    dfs(board, 0);
  }
};

```
