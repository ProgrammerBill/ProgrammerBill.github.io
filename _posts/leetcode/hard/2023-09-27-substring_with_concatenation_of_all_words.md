---
layout:     post
title:      "substring_with_concatenation_of_all_words"
summary:    "\"default\""
date:       2023-09-27 17:37:32
author:     "Bill"
header-img: "img/bill/header-posts/2023-03-11-header.jpg"
catalog: true
stickie: false
hide: false
life: false
guitartab: false
tags:
    - default
---

# 30. Substring With Concatenation Of All Words


You are given a string s and an array of strings words. All the strings of words are of the same length.

A concatenated substring in s is a substring that contains all the strings of any permutation of words concatenated.

    For example, if words = ["ab","cd","ef"], then "abcdef", "abefcd", "cdabef", "cdefab", "efabcd", and "efcdab" are all concatenated strings. "acdbef" is not a concatenated substring because it is not the concatenation of any permutation of words.

Return the starting indices of all the concatenated substrings in s. You can return the answer in any order.

```
Example 1:

Input: s = "barfoothefoobarman", words = ["foo","bar"]
Output: [0,9]
Explanation: Since words.length == 2 and words[i].length == 3, the concatenated substring has to be of length 6.
The substring starting at 0 is "barfoo". It is the concatenation of ["bar","foo"] which is a permutation of words.
The substring starting at 9 is "foobar". It is the concatenation of ["foo","bar"] which is a permutation of words.
The output order does not matter. Returning [9,0] is fine too.

Example 2:

Input: s = "wordgoodgoodgoodbestword", words = ["word","good","best","word"]
Output: []
Explanation: Since words.length == 4 and words[i].length == 4, the concatenated substring has to be of length 16.
There is no substring of length 16 in s that is equal to the concatenation of any permutation of words.
We return an empty array.

Example 3:

Input: s = "barfoofoobarthefoobarman", words = ["bar","foo","the"]
Output: [6,9,12]
Explanation: Since words.length == 3 and words[i].length == 3, the concatenated substring has to be of length 9.
The substring starting at 6 is "foobarthe". It is the concatenation of ["foo","bar","the"] which is a permutation of words.
The substring starting at 9 is "barthefoo". It is the concatenation of ["bar","the","foo"] which is a permutation of words.
The substring starting at 12 is "thefoobar". It is the concatenation of ["the","foo","bar"] which is a permutation of words.



Constraints:

    1 <= s.length <= 104
    1 <= words.length <= 5000
    1 <= words[i].length <= 30
    s and words[i] consist of lowercase English letters.

```

# Solution

本次解决方法参考了官方解答，使用滑动窗口方法。难点在于滑动窗口只需在word size内作为起点即可，后续的起点的结果都会被在word size内出发的结果所包含。

```c++
vector<int> findSubstring(string s, vector<string>& words) {
  int s_size = s.size();
  int word_size = words.size();
  int word_len = words[0].size();
  vector<int> ret;
  for (int i = 0; i < word_len && i <= s_size - (word_size * word_len); i++) {
    map<string, int> window;
    for (int j = i; j < i + word_size * word_len; j += word_len) {
      string tmp = s.substr(j, word_len);
      ++window[tmp];
    }
    for (auto word: words) {
      if (--window[word] == 0) {
        window.erase(word);
      }
    }

    for (int w = i; w < s_size - (word_size * word_len) + 1; w += word_len) {
      if (w >= word_len) {
        string next = s.substr(w + (word_size - 1) * word_len, word_len);
        if (++window[next] == 0) {
          window.erase(next);
        }
        string last = s.substr(w - word_len, word_len);
        if (--window[last] == 0) {
          window.erase(last);
        }
      }
      if (window.empty()) {
        ret.push_back(w);
      }
    }
  }
  return ret;
}
```
