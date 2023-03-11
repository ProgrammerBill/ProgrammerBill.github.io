---
layout:     post
title:      "Climbing Stairs"
summary:    "\"爬楼梯\""
date:       2023-03-11 13:25:14
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

# Climbing Stairs

You are climbing a staircase. It takes n steps to reach the top.

Each time you can either climb 1 or 2 steps. In how many distinct ways can you climb to the top?

```c++
Example 1:

Input: n = 2
Output: 2
Explanation: There are two ways to climb to the top.
1. 1 step + 1 step
2. 2 steps
Example 2:

Input: n = 3
Output: 3
Explanation: There are three ways to climb to the top.
1. 1 step + 1 step + 1 step
2. 1 step + 2 steps
3. 2 steps + 1 step
```


## C++ Solution

首先发现规律f(n) = f(n-1) + f(n-2), 但是以递归的提交会导致超时，
所以以迭代的方式再实现如下：

```c++
int climbStairs(int n) {
    if (n == 1) {
        return 1;
    }
    if (n == 2) {
        return 2;
    }
    int left = 1;
    int right = 2;
    int cur = 0;
    for (int i = 3; i <= n; i++) {
        cur = left + right;
        left = right;
        right = cur;
    }
    return cur;
}
```

