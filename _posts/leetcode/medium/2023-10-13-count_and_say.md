---
layout:     post
title:      "Count and Say"
summary:    "\"default\""
date:       2023-10-13 11:01:03
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

# Count and Say


The count-and-say sequence is a sequence of digit strings defined by the recursive formula:

    countAndSay(1) = "1"
    countAndSay(n) is the way you would "say" the digit string from countAndSay(n-1), which is then converted into a different digit string.

To determine how you "say" a digit string, split it into the minimal number of substrings such that each substring contains exactly one unique digit. Then for each substring, say the number of digits, then say the digit. Finally, concatenate every said digit.

For example, the saying and conversion for digit string "3322251":

Given a positive integer n, return the nth term of the count-and-say sequence.

```

Example 1:

Input: n = 1
Output: "1"
Explanation: This is the base case.

Example 2:

Input: n = 4
Output: "1211"
Explanation:
countAndSay(1) = "1"
countAndSay(2) = say "1" = one 1 = "11"
countAndSay(3) = say "11" = two 1's = "21"
countAndSay(4) = say "21" = one 2 + one 1 = "12" + "11" = "1211"
```

# Solution

```c++
string countAndSay(int n) {
  if (n == 1) {
    return "1";
  }
  string lastStr= countAndSay(n - 1);
  string ans;
  int len = lastStr.size();
  int begin = 0, end = 0;
  while (end <= len) {
    while (end <= len && lastStr[begin] == lastStr[end]) {
      end++;
    }
    int count = end - begin;
    ans.push_back('0' + count);
    ans.push_back(lastStr[begin]);
    begin = end;
    end++;
  }
  return ans;
}
```
