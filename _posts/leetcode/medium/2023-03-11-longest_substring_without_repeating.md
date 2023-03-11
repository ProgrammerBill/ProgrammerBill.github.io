---
layout:     post
title:      "Longest Substring Without Repeating"
summary:    "无重复字符的最长子串"
date:       2023-03-11 11:00:21
author:     "Bill"
header-img: "img/bill/header-posts/2023-03-11-header.jpg"
catalog: true
hide : false
tags:
    - default
---

# Longest Substring Without Repeating Characters


Given a string s, find the length of the longest substring without repeating characters.


```
Example 1:

Input: s = "abcabcbb"
Output: 3
Explanation: The answer is "abc", with the length of 3.
Example 2:

Input: s = "bbbbb"
Output: 1
Explanation: The answer is "b", with the length of 1.
Example 3:

Input: s = "pwwkew"
Output: 3
Explanation: The answer is "wke", with the length of 3.
Notice that the answer must be a substring, "pwke" is a subsequence and not a substring.
Example 4:

Input: s = ""
Output: 0


Constraints:

0 <= s.length <= 5 * 104
s consists of English letters, digits, symbols and spaces.
```
## C++ Solution

该问题用暴力方式去解的话，提交会提示超时，所以需要使用些技巧。以abcabcbb这个字符串为例，检测不重复字符可以使用set数据结构
解决，可以观察得出，以第一个字符a为起点，其最长不重复字符串到第三个字符c，而以第二个字符b为起点，最长的字符串到第四个字符。
其规律在于不同的起始点，随着起始字符的右移，结束字符也会右移，所以可以通过时间复杂度为O(n)，空间复杂度为O(ASCII字符集)的方法解决，即滑动窗口方式。

```c++
#include<iostream>
#include<string>
#include<set>
using namespace std;
class Solution {
public:
    int lengthOfLongestSubstring(string s) {
      int left = 0, right = 0;
      int len = s.length();
      int ans = 0;
      set<char> uniqueSet;
      for (left = 0 ; left < len; left++) {
        uniqueSet.clear();
        right = left;
        while (right < len) {
          if (uniqueSet.count(s[right]) == 0) {
            uniqueSet.insert(s[right++]);
            continue;
          }
          else {
            break;
          }
        }
        int currentLen = uniqueSet.size();
        if (currentLen > ans) {
          ans = currentLen;
        }
      }
      return ans;
    }
};

void test(string input, int expect) {
  Solution *solution = new Solution();
  int ans = solution->lengthOfLongestSubstring(input);
  if (ans == expect) {
    cout<<"test passed!"<<endl;
  } else {
    cout<<"test failed!"<<endl;
  }
  delete solution;
}

int main() {
  test(string("abcabcbb"), 3);
  test(string("bbbbb"), 1);
  test(string("pwwkew"), 3);
  test(string(""), 0);
  test(string("a"), 1);
  test(string(" "), 1);
}
```
