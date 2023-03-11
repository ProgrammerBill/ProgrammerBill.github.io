---
layout:     post
title:      "Search Insert Position"
summary:    "\"搜索插入位置\""
date:       2023-03-11 13:18:23
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

# Search Insert Position

Given a sorted array of distinct integers and a target value, return the index if the target is found. If not, return the index where it would be if it were inserted in order.

You must write an algorithm with O(log n) runtime complexity.

```
Example 1:

Input: nums = [1,3,5,6], target = 5
Output: 2
Example 2:

Input: nums = [1,3,5,6], target = 2
Output: 1
Example 3:

Input: nums = [1,3,5,6], target = 7
Output: 4
```

## C++ Solution

```c++
int searchInsert(vector<int>& nums, int target) {
    int left = 0;
    int right = nums.size() - 1;
    while (left +1 < right) {
        int mid = (left + right) / 2;
        int val = nums[mid];
        if (val == target) return mid;
        else if (target < val && mid > 0) {
            right = mid - 1;
        } else if (target > val) {
            left = mid + 1;
        }
    }
    if (nums[left] < target && nums[right] > target){
        return left + 1;
    } else if (nums[left] == target) {
        return left;
    } else if (nums[right] == target) {
        return right;
    }  else if(nums[left] > target) {
        return left;
    } else {
        return right + 1;
    }
}
```

