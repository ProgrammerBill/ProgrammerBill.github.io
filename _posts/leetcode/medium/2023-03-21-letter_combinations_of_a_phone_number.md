---
layout:     post
title:      "Letter Combinations of a Phone Number"
summary:    "\"电话号码的字母组合\""
date:       2023-03-21 22:48:57
author:     "Bill"
header-img: "img/bill/header-posts/2023-03-21-header.jpg"
catalog: true
stickie: false
hide: true
life: false
guitartab: false
tags:
    - default
---

# 17. Letter Combinations of a Phone Number

Given a string containing digits from 2-9 inclusive, return all possible letter combinations that the number could represent. Return the answer in any order.

A mapping of digits to letters (just like on the telephone buttons) is given below. Note that 1 does not map to any letters.

```
Example 1:

Input: digits = "23"
Output: ["ad","ae","af","bd","be","bf","cd","ce","cf"]
Example 2:

Input: digits = ""
Output: []
Example 3:

Input: digits = "2"
Output: ["a","b","c"]
```


# C++ Solution

一开始用的是Recursive的方法，直接LeetCode给我报Stack Overflow了，改为使用迭代的方式：


```c++
 string numberToLetter(int num) {
  switch (num) {
    case 2:
      return "abc";
    case 3:
      return "def";
    case 4:
      return "ghi";
    case 5:
      return "jkl";
    case 6:
      return "mno";
    case 7:
      return "pqrs";
    case 8:
      return "tuv";
    case 9:
      return "wxyz";
  }
  return "";
}

vector<string> letterCombinations(string digits) {
  if (digits.empty()) {
    return vector<string>();
  }

  vector<string> result{""};
  for (char digit : digits) {
    string letters = numberToLetter(digit - '0');
    if (letters.empty()) {
      continue;
    }

    vector<string> newResult;
    for (char letter : letters) {
      for (string str : result) {
        newResult.push_back(str + letter);
      }
    }
    result = newResult;
  }

  return result;
}
```

