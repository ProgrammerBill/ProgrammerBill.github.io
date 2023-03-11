---
layout:     post
title:      "Longest Palindromic Substring"
summary:    "\"最长回文子串\""
date:       2023-03-11 12:43:15
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

# Longest Palindromic Substring

Given a string s, return the longest palindromic substring in s.

```
Example 1:

Input: s = "babad"
Output: "bab"
Note: "aba" is also a valid answer.
Example 2:

Input: s = "cbbd"
Output: "bb"
Example 3:

Input: s = "a"
Output: "a"
Example 4:

Input: s = "ac"
Output: "a"


Constraints:

1 <= s.length <= 1000
s consist of only digits and English letters.
```

## C++ Solution

思路: 开始想遍历所有字符串，以某个字符为中心，向两边不断检索，遇到边界或者不相等的字符时停止并返回，测试babad的时候可以奏效，但是碰到类似cbbd的时候才发现，原来也可以没有中心字符。为了保持之前的思想，将原来的字符进行扩展，在每个字符中间插入非数字和字母的桩，这里的实现我是以"?"为桩，那么cbbd就变成了“c?b?b?d”,所以也可以通过中间的问号进行两边扩展，同时能够兼容之前的babad的逻辑("b?a?b?a?d"),当然最后以实际字符且不带问号的子字符串，选择长度最长的返回。


```c++
#include<iostream>
#include<string>
using namespace std;

class Solution {
public:
    string longestPalindrome(string s) {
      int left, right;
      int max_len = 0;
      int len = s.length();
      const char pole = '?';
      string fix_src(len * 2 - 1, pole);
      for (int i = 0; i < len; i++) {
        fix_src[2 * i] = s[i];
      }
      int max_left,max_right = 0;
      int fix_len = fix_src.length();
      for (int i = 0; i < fix_len; i++) {
        left = right = i;
        while (left >= 0 && right < fix_len && fix_src[left] == fix_src[right]) {
          left--;
          right++;
          if (left < 0 || right >= fix_len) {
            break;
          }
        }
        left++;
        right--;
        int count_pole = 0;
        for (char val : fix_src.substr(left, right - left + 1)){
          if (val == pole) {
            count_pole++;
          }
        }
        if (right - left + 1 - count_pole > max_len) {
          max_len = right - left + 1 - count_pole;
          max_left = left;
          max_right = right;
        }
      }
      string str =  fix_src.substr(max_left, max_right - max_left + 1);
      string ans;
      for (int i = 0; i < str.length(); i++) {
        if (str[i] != pole) {
          char tmp = str[i];
          ans.push_back(tmp);
        }
      }
      return ans;
    }
};

void test(string input, string expect) {
  Solution s;
  string ret = s.longestPalindrome(input);
  cout<<"ret = "<<ret<<endl;
  if (ret.compare(expect) == 0) {
    cout<<"tests passed!"<<endl;
  } else {
    cout<<"tests failed!"<<endl;
  }
}

int main() {
  test(string("babad"), string("bab"));
  test(string("cbbd"), string("bb"));
  test(string("a"), string("a"));
  test(string("ac"), string("a"));
  test(string("ccd"), string("cc"));
}
```


