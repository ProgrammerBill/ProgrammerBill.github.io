---
layout:     post
title:      "Jump Game II"
summary:    "\"default\""
date:       2023-10-30 10:34:48
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

# Jump Game II

You are given a 0-indexed array of integers nums of length n. You are initially positioned at nums[0].

Each element nums[i] represents the maximum length of a forward jump from index i. In other words, if you are at nums[i], you can jump to any nums[i + j] where:

```
0 <= j <= nums[i] and
i + j < n
Return the minimum number of jumps to reach nums[n - 1]. The test cases are generated such that you can reach nums[n - 1].



Example 1:

Input: nums = [2,3,1,1,4]
Output: 2
Explanation: The minimum number of jumps to reach the last index is 2. Jump 1 step from index 0 to 1, then 3 steps to the last index.
Example 2:

Input: nums = [2,3,
```

# Solution

```
class Solution {
  public:
  int jump(vector<int>& nums) {
    int n = nums.size();
    int dp[1001] = {0};
    dp[0] = 0;
    dp[1] = 0;
    for (int i = 2; i <= n; i++) {
      int min = INT_MAX;
      for (int j = i - 1; j > 0; j--) {
        if (i - j <= nums[j - 1] && dp[j] + 1 < min) {
          min = dp[j] + 1;
        }
      }
      dp[i] = min;
    }
    cout<<endl;
    return dp[n];
  }
};
```
