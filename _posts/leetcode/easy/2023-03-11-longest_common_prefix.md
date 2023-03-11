---
layout:     post
title:      "Longest Common Prefix"
summary:    "\"最长公共前缀\""
date:       2023-03-11 13:05:02
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

# Longest Common Prefix

Write a function to find the longest common prefix string amongst an array of strings.
If there is no common prefix, return an empty string "".

```
Example 1:
Input: strs = ["flower","flow","flight"]
Output: "fl"
Example 2:
Input: strs = ["dog","racecar","car"]
Output: ""
Explanation: There is no common prefix among the input strings.
Constraints:
1 <= strs.length <= 200
0 <= strs[i].length <= 200
strs[i] consists of only lowercase English letters.
```

## C++ Solution

```c++
class Solution {
  public:
      string longestCommonPrefix(vector <string>&strs) {
          if (strs.empty()) {
              return "";
          }
          if (strs.size() == 1) {
              return strs[0];
          }
          string temp = strs[0];
          int index;
          for (index = 0; index < temp.size(); index++) {
              for (int i = 1; i < strs.size(); i++) {
                  if (index >= strs[i].size() ||
                          strs[i][index] != temp[index]) {
                      return temp.substr(0, index);
                  }
              }
          }
          return temp;
      }
}
```

