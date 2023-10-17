---
layout:     post
title:      "First Missing Positive"
summary:    "\"default\""
date:       2023-10-17 13:57:14
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


# First Missing Positive


Given an unsorted integer array nums, return the smallest missing positive integer.

You must implement an algorithm that runs in O(n) time and uses O(1) auxiliary space.


```
Example 1:

Input: nums = [1,2,0]
Output: 3
Explanation: The numbers in the range [1,2] are all in the array.

Example 2:

Input: nums = [3,4,-1,1]
Output: 2
Explanation: 1 is in the array but 2 is missing.

Example 3:

Input: nums = [7,8,9,11,12]
Output: 1
Explanation: The smallest positive integer 1 is missing.
```

# Solution

```c++
int firstMissingPositive(vector<int>& nums) {
  int len = nums.size();
  for (int i = 0 ; i < len; i++) {
    if (nums[i] <= 0) {
      nums[i] = len + 1;
    }
  }
  for (int i = 0; i < len; i++) {
    int num = abs(nums[i]);
    if (num <= len) {
      nums[num - 1] = -abs(nums[num - 1]);
    }
  }
  for (int i = 0; i < len; i++) {
    if (nums[i] > 0) {
      return i + 1;
    }
  }
  return len + 1;
}
```

