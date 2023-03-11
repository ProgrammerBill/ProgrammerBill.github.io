---
layout:     post
title:      "Reverse Integer"
summary:    "\"整数反转\""
date:       2023-03-11 12:48:50
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

# Reverse Integer

Category	Difficulty	Likes	Dislikes
algorithms	Medium (26.18%)	5870	8734
Tags
Companies
Given a signed 32-bit integer x, return x with its digits reversed. If reversing x causes the value to go outside the signed 32-bit integer range [-231, 231 - 1], then return 0.

Assume the environment does not allow you to store 64-bit integers (signed or unsigned).

```
Example 1:

Input: x = 123
Output: 321
Example 2:

Input: x = -123
Output: -321
Example 3:

Input: x = 120
Output: 21
Example 4:

Input: x = 0
Output: 0


Constraints:

-231 <= x <= 231 - 1
```

## C++ Solution

思路是首先不断除10获取低位的数字，然后通过FIFO的数据结构，从头部拿出并累计成新数字。最大的问题是当新数字超过INT的范围时，需要返回0，这里的做法是用更大的类型去进行计算，然后通过`INT_MAX`和`INT_MIN`比较判断。

```c++
class Solution {
public:
   int reverse(int x) {
    list <int> myList;
    while (x) {
      int digit = x % 10;
      x = x / 10;
      myList.push_back(digit);
    }

    long ans = 0;
    while (!myList.empty()) {
      ans = ans * 10 + myList.front();
      myList.pop_front();
    }
    if (ans > INT_MAX || ans < INT_MIN) {
      return 0;
    }
    return ans;
  }
};
```

