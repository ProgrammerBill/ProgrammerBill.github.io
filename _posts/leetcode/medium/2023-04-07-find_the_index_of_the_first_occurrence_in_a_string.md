---
layout:     post
title:      "Find the Index of the First Occurrence in a String"
summary:    "\"找出字符串中第一个匹配项的下标\""
date:       2023-04-07 23:42:40
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

# Find the Index of the First Occurrence in a String

Given two strings needle and haystack, return the index of the first occurrence of needle in haystack, or -1 if needle is not part of haystack.

```
Example 1:

Input: haystack = "sadbutsad", needle = "sad"
Output: 0
Explanation: "sad" occurs at index 0 and 6.
The first occurrence is at index 0, so we return 0.
Example 2:

Input: haystack = "leetcode", needle = "leeto"
Output: -1
Explanation: "leeto" did not occur in "leetcode", so we return -1.
```

# C++ Solution

## 暴力解法1

```c++
class Solution {
public:
    int strStr(string haystack, string needle) {
        size_t pos = haystack.find(needle);
            if (pos != std::string::npos) {
                return pos;
            } else {
                return -1;
        }
    }
};
```

## 暴力解法2

```c++
class Solution {
public:
 int strStr(string haystack, string needle) {
    int src_len = haystack.length();
    int dst_len = needle.length();
    for (int i = 0; i <= src_len - dst_len; i++) {
      string tmp = haystack.substr(i, dst_len);
      if (tmp.compare(needle) == 0) {
        return i;
      }
    }
    return -1;
  }
};
```

## KMP

不得不说，加上了copilot X后，AI能理解我的意图，很快就自动填充了可能的方法。

```c++
int strStr(string srcs, string pattern) {
  int src_len = srcs.size();
  int pattern_len = pattern.size();
  if (src_len < pattern_len) {
    return -1;
  }
  int next[pattern_len];
  next[0] = 0;
  int i = 0;
  int j = 1;
  // 计算next数组
  for (; j < pattern_len; j++) {
    while (i > 0 && pattern[i] != pattern[j]) {
      i = next[i - 1];
    }
    if (pattern[i] == pattern[j]) {
      i++;
    }
    next[j] = i;
  }
  // 匹配
  for (i = 0, j = 0; i < src_len && j < pattern_len; i++) {
    while (j > 0 && srcs[i] != pattern[j]) {
      j = next[j - 1];
    }
    if (srcs[i] == pattern[j]) {
      j++;
    }
  }
  return j == pattern_len ? i - j : -1;
}
```

具体的原理可以参考[简单题学 KMP 算法](https://leetcode.cn/problems/find-the-index-of-the-first-occurrence-in-a-string/solutions/575568/shua-chuan-lc-shuang-bai-po-su-jie-fa-km-tb86/)
