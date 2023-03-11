---
layout:     post
title:      "Regular Expression Matching"
summary:    "\"正则表达式匹配\""
date:       2023-03-11 12:55:52
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

# Regular Expression Matching


Given an input string s and a pattern p, implement regular expression matching with support for '.' and '*' where:

- '.' Matches any single character.​​​​
- '*' Matches zero or more of the preceding element.
The matching should cover the entire input string (not partial).



```
 Example 1:

 Input: s = "aa", p = "a"
 Output: false
 Explanation: "a" does not match the entire string "aa".
 Example 2:

 Input: s = "aa", p = "a*"
 Output: true
 Explanation: '*' means zero or more of the preceding element, 'a'. Therefore, by repeating 'a' once, it becomes "aa".
 Example 3:

 Input: s = "ab", p = ".*"
 Output: true
 Explanation: ".*" means "zero or more (*) of any character (.)".
 Example 4:

 Input: s = "aab", p = "c*a*b"
 Output: true
 Explanation: c can be repeated 0 times, a can be repeated 1 time. Therefore, it matches "aab".
 Example 5:

 Input: s = "mississippi", p = "mis*is*p*."
 Output: false


  Constraints:

  1 <= s.length <= 20
  1 <= p.length <= 30
  s contains only lowercase English letters.
  p contains only lowercase English letters, '.', and '*'.
  It is guaranteed for each appearance of the character '*', there will be a previous valid character to match.
```

## C++ Solution

```c++
class Solution {
  public:
    bool isMatch(string s, string p) {
      if (p.length() == 0) {
          return s.length() == 0 ? true : false;
      }
      bool first_match = false;
      if (s.length() > 0 && (p[0] == '.' || p[0] == s[0])) {
          first_match = true;
      }
      if (p.length() >= 2 && p[1] == '*') {
          return isMatch(s, p.substr(2)) || (first_match && isMatch(s.substr(1), p));
      } else {
          return first_match && isMatch(s.substr(1), p.substr(1));
      }
    }
}
```


