---
layout:     post
title:      "Maximum Subarray"
summary:    "\"default\""
date:       2023-11-17 09:27:43
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

# Maximum Subarray

Given an integer array nums, find the
subarray
with the largest sum, and return its sum.


```
Example 1:

Input: nums = [-2,1,-3,4,-1,2,1,-5,4]
Output: 6
Explanation: The subarray [4,-1,2,1] has the largest sum 6.

Example 2:

Input: nums = [1]
Output: 1
Explanation: The subarray [1] has the largest sum 1.

Example 3:

Input: nums = [5,4,-1,7,8]
Output: 23
Explanation: The subarray [5,4,-1,7,8] has the largest sum 23.



Constraints:

    1 <= nums.length <= 105
    -104 <= nums[i] <= 104



Follow up: If you have figured out the O(n) solution, try coding another solution using the divide and conquer approach, which is more subtle.
```


# solution

```c++
class Solution {
public:
    int maxSubArray(vector<int>& nums) {
      int max = INT_MIN;
      int len = nums.size();
      int tmp = 0;
      for (int i = 0 ; i < len; i++) {
        tmp = std::max(tmp + nums[i], nums[i]);
        max = tmp > max ? tmp : max;
      }
      return max;
    }
};
```
