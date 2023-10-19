---
layout:     post
title:      "Multiply Strings"
summary:    "\"default\""
date:       2023-10-19 15:55:34
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


# Multiply Strings

Given two non-negative integers num1 and num2 represented as strings, return the product of num1 and num2, also represented as a string.

Note: You must not use any built-in BigInteger library or convert the inputs to integer directly.

```

Example 1:

Input: num1 = "2", num2 = "3"
Output: "6"
Example 2:

Input: num1 = "123", num2 = "456"
Output: "56088"


Constraints:

1 <= num1.length, num2.length <= 200
num1 and num2 consist of digits only.
Both num1 and num2 do not contain any leading zero, except the number 0 itself.
```

# Solution

```c++
class Solution {
  public:
  string multiply(string num1, string num2) {
    int len1 = num1.size();
    int len2 = num2.size();
    string ans;
    for (int i = 0; i < len1 + 1 + len2; i++) {
        ans.push_back('0');
    }
    for (int j = len2 - 1; j >= 0; j--) {
      int carry = 0;
      for (int i = len1 - 1; i >= 0; i--) {
        int tmp = (num1[i] - '0') * (num2[j] - '0');
        int round = len1 - 1 - i + len2 - 1 - j;
        int val = tmp + carry;
        val += (ans[round] - '0');
        ans[len2 - 1 - j + len1 - 1 -i] = val % 10 + '0';
        carry = val >= 10 ? val / 10 : 0;
      }
      if (carry != 0) {
        ans[len1 + len2 - 1 - j] = carry + '0';
      }
    }
    reverse(ans.begin(), ans.end());
    int nextZeroIndex;
    for (nextZeroIndex = 0; nextZeroIndex < ans.size() - 1; nextZeroIndex++) {
      if (ans[nextZeroIndex] != '0') {
        break;
      }
    }
    return ans.substr(nextZeroIndex);
  }
};
```
