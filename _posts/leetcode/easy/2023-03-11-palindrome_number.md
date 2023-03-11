---
layout:     post
title:      "Palindrome Number"
summary:    "\"回文数\""
date:       2023-03-11 12:54:45
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

# Palindrome Number

Given an integer x, return true if x is palindrome integer.

An integer is a palindrome when it reads the same backward as forward. For example, 121 is palindrome while 123 is not.

```
Example 1:

Input: x = 121
Output: true
Example 2:

Input: x = -121
Output: false
Explanation: From left to right, it reads -121. From right to left, it becomes 121-. Therefore it is not a palindrome.
Example 3:

Input: x = 10
Output: false
Explanation: Reads 01 from right to left. Therefore it is not a palindrome.
Example 4:

Input: x = -101
Output: false


Constraints:

-231 <= x <= 231 - 1
```

## C++ Solution

思路是转化为string，然后左右指针对比，一旦有不同就返回false，直到指针相遇。当然负数立马返回false。

```c++
class Solution {
public:
    bool isPalindrome(int x) {
    if (x < 0) {
      return false;
    } else {
      char tmp[32];
      sprintf(tmp, "%d", x);
      string str = string(tmp);
      int left = 0;
      int right = str.length() - 1;
      while (left < right) {
        if (str[left] != str[right]) {
          return false;
        }
        left++;
        right--;
      }
    }
    return true;
  }
};
```

