---
layout:     post
title:      "Group Anagrams"
summary:    "\"default\""
date:       2023-11-03 11:30:52
author:     "Bill"
header-img: "img/bill/header-posts/2023-11-03-header.jpg"
catalog: true
stickie: false
hide: true
life: false
guitartab: false
tags:
    - default
---

# Group Anagrams


Given an array of strings strs, group the anagrams together. You can return the answer in any order.

An Anagram is a word or phrase formed by rearranging the letters of a different word or phrase, typically using all the original letters exactly once.

```

Example 1:

Input: strs = ["eat","tea","tan","ate","nat","bat"]
Output: [["bat"],["nat","tan"],["ate","eat","tea"]]

Example 2:

Input: strs = [""]
Output: [[""]]

Example 3:

Input: strs = ["a"]
Output: [["a"]]

```

# Solution

```c++
class Solution {
  public:
  vector<vector<string>> groupAnagrams(vector<string>& strs) {
    vector<vector<string>> res;
    vector<map<char, int>> myVec;
    for (auto i : strs) {
      map<char, int> tmp;
      for (auto j : i) {
        tmp[j]++;
      }
      myVec.push_back(tmp);
    }
    set<map<char, int>> mySet;
    for (int i = 0; i < strs.size(); i++) {
      if (mySet.count(myVec[i]) == 0) {
        vector<string> tmp;
        tmp.push_back(strs[i]);
        for (int j = i + 1; j < strs.size(); j++) {
          if (myVec[i] == myVec[j]) {
            tmp.push_back(strs[j]);
          }
        }
        res.push_back(tmp);
        mySet.insert(myVec[i]);
      }
    }
    return res;
  }
};
```

