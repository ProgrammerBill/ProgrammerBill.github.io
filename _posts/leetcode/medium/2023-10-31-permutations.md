---
layout:     post
title:      "Permutations"
summary:    "\"default\""
date:       2023-10-31 10:34:37
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

# Permutations


Given an array nums of distinct integers, return all the possible permutations. You can return the answer in any order.

```
Example 1:

Input: nums = [1,2,3]
Output: [[1,2,3],[1,3,2],[2,1,3],[2,3,1],[3,1,2],[3,2,1]]

Example 2:

Input: nums = [0,1]
Output: [[0,1],[1,0]]

Example 3:

Input: nums = [1]
Output: [[1]]
```

# Solution

```c++
class Solution {
  private:
  set<vector<int>> mySet;
  void permuteImpl(vector<int>& nums, int begin, int len) {
    if (begin == len) {
      return;
    }
    for (int i = begin; i < len; i++) {
      swap(nums[begin], nums[i]);
      mySet.insert(nums);
      permuteImpl(nums, begin + 1, len);
      swap(nums[begin], nums[i]);
    }
  }

  public:
  vector<vector<int>> permute(vector<int>& nums) {
    int len = nums.size();
    permuteImpl(nums, 0, len);
    vector<vector<int>> ans;
    for (auto item : mySet) {
      ans.push_back(item);
    }
    return ans;
  }
};
```
