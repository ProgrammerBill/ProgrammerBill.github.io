---
layout:     post
title:      "Fibonacci Number"
summary:    "\"斐波那契数\""
date:       2023-03-11 14:20:44
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


# Fibonacci Number

The Fibonacci numbers, commonly denoted F(n) form a sequence, called the Fibonacci sequence, such that each number is the sum of the two preceding ones, starting from 0 and 1. That is,

```
F(0) = 0,   F(1) = 1
F(N) = F(N - 1) + F(N - 2), for N > 1.
Given N, calculate F(N).
```

```
Eample 1:

Input: 2
Output: 1
Explanation: F(2) = F(1) + F(0) = 1 + 0 = 1.
Example 2:

Input: 3
Output: 2
Explanation: F(3) = F(2) + F(1) = 1 + 1 = 2.
Example 3:

Input: 4
Output: 3
Explanation: F(4) = F(3) + F(2) = 2 + 1 = 3.
```

## Java Solution:

**recursion**

```java
public int fib(int N) {
        if(N == 0){
            return 0;
        }
        else if(N == 1){
            return 1;
        }
        return fib(N-1) + fib(N-2);
    }
```

**iteration**

```java
public int fib(int N) {
    int fib_0 = 0;
    int fib_1 = 1;
    int ret = 0;
    if(N == 0) return fib_0;
    if(N == 1) return fib_1;
    for(int i = 1; i < N;i++){
        //fib(N) = fib(N-1) + fib(N-2)
        int left = fib_0;
        int right = fib_1;
        ret = left + right;
        fib_0 = right;
        fib_1 = ret;
    }
    return ret;
}
```

