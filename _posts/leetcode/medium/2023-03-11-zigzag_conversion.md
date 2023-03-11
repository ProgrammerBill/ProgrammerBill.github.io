---
layout:     post
title:      "Zigzag Conversion"
summary:    "\"N 字形变换\""
date:       2023-03-11 12:47:00
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

# Zigzag Conversion

The string "PAYPALISHIRING" is written in a zigzag pattern on a given number of rows like this: (you may want to display this pattern in a fixed font for better legibility)

P   A   H   N
A P L S I I G
Y   I   R
And then read line by line: "PAHNAPLSIIGYIR"

Write the code that will take a string and make this conversion given a number of rows:

string convert(string s, int numRows);


```
 Example 1:

 Input: s = "PAYPALISHIRING", numRows = 3
 Output: "PAHNAPLSIIGYIR"
 Example 2:

 Input: s = "PAYPALISHIRING", numRows = 4
 Output: "PINALSIGYAHRPI"
 Explanation:
 P     I    N
 A   L S  I G
 Y A   H R
 P     I
 Example 3:

 Input: s = "A", numRows = 1
 Output: "A"


  Constraints:

  1 <= s.length <= 1000
  s consists of English letters (lower-case and upper-case), ',' and '.'.
  1 <= numRows <= 1000
```

## C++ Solution

没有想到比较好的方法，这题的思路是先找到竖的集合以及斜的集合，然后通过竖的可以获取到最终的头和尾，竖和斜的集合进行处理就可以组成字符串的中间部分了。


```c++
#include <iostream>
#include <string>
using namespace std;
class Solution {
  public:
    string convert(string s, int numRows) {
      vector<string> zags;
      vector<string> zigs;
      vector<string> middle_vec;
      string header, middle, end;
      int col_index = 0;
      int zig_index = 0;
      if (numRows == 1) {
        return s;
      }
      for (int i = 0; i < s.length(); i += 2 * (numRows - 1)) {
        zags.push_back(s.substr(i, numRows));
      }
      for (int i = numRows; i < s.length(); i += 2 * (numRows - 1)) {
        string tmp = s.substr(i, numRows - 2);
        reverse(tmp.begin(), tmp.end());
        zigs.push_back(tmp);
      }
      while (col_index < zags.size() || zig_index < zigs.size()) {
        if (col_index < zags.size()) {
          header.push_back(zags[col_index][0]);
          if (zags[col_index].size() == numRows) {
            end.push_back(zags[col_index][numRows - 1]);
          }
          if (zags[col_index].size() == numRows) {
            middle_vec.push_back(zags[col_index].substr(1, numRows - 2));
          } else {
            middle_vec.push_back(zags[col_index].substr(1));
          }
          col_index++;
        }
        if (zig_index < zigs.size()) {
          string tmp = zigs[zig_index];
          middle_vec.push_back(zigs[zig_index++]);
        }
      }

      for (int i = 0; i < numRows - 2; i++) {
        int index = 0;
        for (auto str : middle_vec) {
          if (str.size() == numRows - 2) {
            middle.push_back(str[i]);
          } else {
            if (index % 2 == 1){
              if (i > numRows - 2 - str.size() - 1) {
                middle.push_back(str[i - (numRows - 2 - str.size())]);
              }
            } else {
              if (i < str.size()) {
                middle.push_back(str[i]);
              }
            }
          }
          index++;
        }
      }
      return header + middle + end;
    }
};
```

