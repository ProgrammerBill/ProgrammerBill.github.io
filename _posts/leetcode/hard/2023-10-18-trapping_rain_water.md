---
layout:     post
title:      "Trapping Rain Water"
summary:    "\"default\""
date:       2023-10-18 11:34:35
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

# Trapping Rain Water


Given n non-negative integers representing an elevation map where the width of each bar is 1, compute how much water it can trap after raining.

```
Example 1:

Input: height = [0,1,0,2,1,0,1,3,2,1,2,1]
Output: 6
Explanation: The above elevation map (black section) is represented by array [0,1,0,2,1,0,1,3,2,1,2,1]. In this case, 6 units of rain water (blue section) are being trapped.

Example 2:

Input: height = [4,2,0,3,2,5]
Output: 9


Constraints:

    n == height.length
    1 <= n <= 2 * 104
    0 <= height[i] <= 105

```

# Solution

```c++
class Solution {
  public:
  int trap(vector<int>& height) {
    int solidArea = 0;
    int topIndex = 0;
    int topHeight = 0;
    int width = height.size();
    for (int i = 0; i < width; i++) {
      solidArea += height[i];
      if (topHeight < height[i]) {
        topIndex = i;
        topHeight = height[i];
      }
    }
    for (int left = 0; left < topIndex; left++) {
      if (height[left + 1] < height[left]) {
        height[left + 1] = height[left];
      }
    }
    for (int right = width - 1; right > topIndex; right--) {
      if (height[right] > height[right - 1]) {
        height[right - 1] = height[right];
      }
    }
    int fixedArea = 0;
    for (auto item : height) {
      fixedArea += item;
    }
    return fixedArea - solidArea;
  }
};

```

