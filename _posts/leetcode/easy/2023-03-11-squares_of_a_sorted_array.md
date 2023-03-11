---
layout:     post
title:      "Squares of a Sorted Array"
summary:    "\"有序数组的平方\""
date:       2023-03-11 15:51:31
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

# Squares of a Sorted Array


Given an array of integers A sorted in non-decreasing order, return an array of the squares of each number, also in sorted non-decreasing order.


```
Example 1:

Input: [-4,-1,0,3,10]
Output: [0,1,9,16,100]
Example 2:

Input: [-7,-3,2,3,11]
Output: [4,9,9,49,121]


Note:

1 <= A.length <= 10000
-10000 <= A[i] <= 10000
A is sorted in non-decreasing order.
```


## Java Solution:

```java
class Solution {
    private boolean less(int v, int w) {
        return v < w;
    }

    private void exch(int[] a, int i, int j) {
        int t = a[i];
        a[i] = a[j];
        a[j] = t;
    }


    public int[] sortedSquares(int[] A) {
        int N = A.length;
        int [] tmp = new int[N];
        for (int i = 0; i < N; i++) {
            tmp[i] = Math.abs(A[i]);
        }

        for(int i = 1 ; i < N; i++){
            for(int j = i; j > 0 && less(tmp[j], tmp[j-1]);j--){
                exch(tmp, j, j-1);
            }
        }

        for (int i = 0; i <N; i++) {
            int var = tmp[i];
            tmp[i] = var * var;
        }
        return tmp;
    }
}
```


