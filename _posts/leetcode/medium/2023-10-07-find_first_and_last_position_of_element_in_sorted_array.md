---
layout:     post
title:      "Find First and Last Position of Element in Sorted Array"
summary:    "\"default\""
date:       2023-10-07 09:43:09
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


# 34. Find First and Last Position of Element in Sorted Array


Given an array of integers nums sorted in non-decreasing order, find the starting and ending position of a given target value.

If target is not found in the array, return [-1, -1].

You must write an algorithm with O(log n) runtime complexity.


```
Example 1:

Input: nums = [5,7,7,8,8,10], target = 8
Output: [3,4]
Example 2:

Input: nums = [5,7,7,8,8,10], target = 6
Output: [-1,-1]
Example 3:

Input: nums = [], target = 0
Output: [-1,-1]


Constraints:

0 <= nums.length <= 105
-109 <= nums[i] <= 109
nums is a non-decreasing array.
-109 <= target <= 109
```

# Solution

```c++
vector<int> searchRange(vector<int>& nums, int target) {
    int left = -1, right = -1;
    for (int i = 0; i < nums.size(); i++) {
        if (nums[i] == target) {
            left = i;
            right = left;
            for (int j = left; j < nums.size() && nums[j] == target; j++) {
                right = j;
            }
            break;
        }
    }
    return {left, right};
}
```

