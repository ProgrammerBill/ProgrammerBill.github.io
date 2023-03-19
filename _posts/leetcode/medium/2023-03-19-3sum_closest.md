---
layout:     post
title:      "3Sum Closest"
summary:    "\"最接近的三数之和\""
date:       2023-03-19 23:29:37
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

# 3Sum Closest
Given an integer array nums of length n and an integer target, find three integers in nums such that the sum is closest to target.

Return the sum of the three integers.

You may assume that each input would have exactly one solution.

```
Example 1:

Input: nums = [-1,2,1,-4], target = 1
Output: 2
Explanation: The sum that is closest to the target is 2. (-1 + 2 + 1 = 2).
Example 2:

Input: nums = [0,0,0], target = 1
Output: 0
Explanation: The sum that is closest to the target is 0. (0 + 0 + 0 = 0).
```

# C++ Solution

```
#include <vector>
#include <algorithm>
#include <climits>
using namespace std;
class Solution
{
public:
    int threeSumClosest(vector<int> &nums, int target)
    {
        sort(nums.begin(), nums.end());
        int len = nums.size();
        int closest = target > 0 ? 100000 : -100000;
        for (int i = 0; i < len; i++)
        {
            int left = i + 1;
            int right = len - 1;
            while (left < right)
            {
                int leftVal = nums[left];
                int rightVal = nums[right];
                int sum = nums[i] + nums[left] + nums[right];
                if (target == sum)
                {
                    return target;
                }
                else if (target > sum)
                {
                    left = left + 1;
                }
                else
                {
                    right = right - 1;
                }
                if (abs(target - closest) > abs(target - sum))
                {
                    closest = sum;
                }
            }
        }
        return closest;
    }
};
```
