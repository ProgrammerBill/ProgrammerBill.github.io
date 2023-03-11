---
layout:     post
title:      "Running Sum of 1d Array"
summary:    "\"一维数组的动态和\""
date:       2023-03-11 16:02:24
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

# Running Sum of 1d Array

Given an array nums. We define a running sum of an array as runningSum[i] = sum(nums[0]…nums[i]).

Return the running sum of nums.



```
Example 1:

Input: nums = [1,2,3,4]
Output: [1,3,6,10]
Explanation: Running sum is obtained as follows: [1, 1+2, 1+2+3, 1+2+3+4].
Example 2:

Input: nums = [1,1,1,1,1]
Output: [1,2,3,4,5]
Explanation: Running sum is obtained as follows: [1, 1+1, 1+1+1, 1+1+1+1, 1+1+1+1+1].
Example 3:

Input: nums = [3,1,2,10,1]
Output: [3,4,6,16,17]


Constraints:

1 <= nums.length <= 1000
-10^6 <= nums[i] <= 10^6
```

## C++ Solution

```c++
class Solution {
public:
    vector<int> runningSum(vector<int>& nums) {
        vector<int> ret;
        int last = 0;
        for(int i = 0 ; i < nums.size(); i++){
            ret.push_back(last + nums[i]);
            last = ret.back();
        }
        return ret;
    }
};
```


