---
layout:     post
title:      "Permutations II"
summary:    "\"default\""
date:       2023-11-02 13:38:45
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

# Permutations II

Given a collection of numbers, nums, that might contain duplicates, return all possible unique permutations in any order.


```
Example 1:

Input: nums = [1,1,2]
Output:
[[1,1,2],
 [1,2,1],
 [2,1,1]]
Example 2:

Input: nums = [1,2,3]
Output: [[1,2,3],[1,3,2],[2,1,3],[2,3,1],[3,1,2],[3,2,1]]
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
  vector<vector<int>> permuteUnique(vector<int>& nums) {
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
