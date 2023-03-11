---
layout:     post
title:      "Number of Good Pairs"
summary:    "\"好数对的数目\""
date:       2023-03-11 16:10:50
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


# Number of Good Pairs

Given an array of integers nums.

A pair (i,j) is called good if nums[i] == nums[j] and i < j.

Return the number of good pairs.


```
Example 1:

Input: nums = [1,2,3,1,1,3]
Output: 4
Explanation: There are 4 good pairs (0,3), (0,4), (3,4), (2,5) 0-indexed.
Example 2:

Input: nums = [1,1,1,1]
Output: 6
Explanation: Each pair in the array are good.
Example 3:

Input: nums = [1,2,3]
Output: 0

Constraints:

1 <= nums.length <= 100
1 <= nums[i] <= 100
```


## Java Solution
```
class Solution {
public:
    int numIdenticalPairs(vector<int>& nums) {
        int ret = 0;
        for(int i = 0; i < nums.size() - 1; i++){
            for(int j = nums.size() - 1; j > i; j--){
                if(nums[i] == nums[j]){
                    ret++;
                }
            }
        }
        return ret;
    }
};
```
