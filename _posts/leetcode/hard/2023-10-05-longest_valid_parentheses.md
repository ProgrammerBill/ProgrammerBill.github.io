---
layout:     post
title:      "Longest Valid Parentheses"
summary:    "\"default\""
date:       2023-10-05 00:32:31
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

# 32. Longest Valid Parentheses

Given a string containing just the characters '(' and ')', return the length of the longest valid (well-formed) parentheses
substring
.


```
Example 1:

Input: s = "(()"
Output: 2
Explanation: The longest valid parentheses substring is "()".
Example 2:

Input: s = ")()())"
Output: 4
Explanation: The longest valid parentheses substring is "()()".
Example 3:

Input: s = ""
Output: 0


Constraints:

0 <= s.length <= 3 * 104
s[i] is '(', or ')'.
```

# Solution

```c++
int longestValidParentheses(string s) {
  stack<int> st;
  int maxans = 0;
  int i = -1;
  st.push(i);
  for (i = 0; i < s.size(); i++) {
    if (s[i] == '(') {
      st.push(i);
    } else {
      st.pop();
      if (st.empty()) {
        st.push(i);
      } else {
        maxans = max(maxans, i - st.top());
      }
    }
  }
  return maxans;
}
```
