---
layout:     post
title:      "Wildcard Matching"
summary:    "\"default\""
date:       2023-10-20 15:27:08
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


# Wildcard Matching


Given an input string (s) and a pattern (p), implement wildcard pattern matching with support for '?' and '*' where:

    '?' Matches any single character.
    '*' Matches any sequence of characters (including the empty sequence).

The matching should cover the entire input string (not partial).

```
Example 1:

Input: s = "aa", p = "a"
Output: false
Explanation: "a" does not match the entire string "aa".

Example 2:

Input: s = "aa", p = "*"
Output: true
Explanation: '*' matches any sequence.

Example 3:

Input: s = "cb", p = "?a"
Output: false
Explanation: '?' matches 'c', but the second letter is 'a', which does not match 'b'.
```

# Solution

```c++
bool isMatch(string s, string p) {
  int indexS = 0;
  int indexP = 0;
  int lenS = s.size();
  int lenP = p.size();
  bool dp[2001][2001] = {false};
  dp[0][0] = true;
  int w;
  for (w = 1; w <= lenP; w++) {
    if (p[w - 1] != '*') {
       break;
    }
  }
  for (int i = 0; i < w; i++) {
    dp[0][i] = true;
  }
  for (int i = 1; i <= lenS; i++) {
    for (int j = 1; j <= lenP; j++) {
      if (s[i - 1] == p[j - 1] || p[j - 1] == '?') {
        dp[i][j] = dp[i - 1][j - 1];
      } else if (p[j - 1] == '*') {
        dp[i][j] = dp[i - 1][j] || dp[i][j - 1];
      }
    }
  }
  return dp[lenS][lenP];
}

```
