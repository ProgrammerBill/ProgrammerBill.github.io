---
layout:     post
title:      "Generate Parentheses"
summary:    "\"括号生成\""
date:       2023-03-30 10:33:07
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


# 22. Generate Parentheses

Given n pairs of parentheses, write a function to generate all combinations of well-formed parentheses.

```
Example 1:

Input: n = 3
Output: ["((()))","(()())","(())()","()(())","()()()"]
Example 2:

Input: n = 1
Output: ["()"]
```

# C++ Solution

```c++
class Solution {
public:
  bool isValid(string s) {
    stack<char> parentheses;
    for (auto character : s) {
      switch (character) {
      case '(':
      case '[':
      case '{':
        parentheses.push(character);
        break;
      case ')':
        if (parentheses.empty() || parentheses.top() != '(') {
          return false;
        }
        if (!parentheses.empty()) {
          parentheses.pop();
        }
        break;
      case ']':
        if (parentheses.empty() || parentheses.top() != '[') {
          return false;
        }
        if (!parentheses.empty()) {
          parentheses.pop();
        }
        break;
      case '}':
        if (parentheses.empty() || parentheses.top() != '{') {
          return false;
        }
        if (!parentheses.empty()) {
          parentheses.pop();
        }
        break;
      }
    }
    return parentheses.empty();
  }
  vector<string> generateParenthesis(int n) {
    vector<string> result{""};
    vector<string> parenthesis{"(", ")"};
    for (int i = 0; i < n * 2; i++) {
      vector<string> newResult;
      for (auto str : result) {
        for (auto symbol : parenthesis) {
          newResult.push_back(str + symbol);
        }
      }
      result = newResult;
    }
    vector<string> validResult;
    for (auto item : result) {
      if (isValid(item)) {
        validResult.push_back(item);
      }
    }
    return validResult;
  }
};
`
