---
layout:     post
title:      "Smallest Range I"
summary:    "\"最小差值 I\""
date:       2023-03-11 15:31:00
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

# Smallest Range I

Given an array A of integers, for each integer A[i] we may choose any x with -K <= x <= K, and add x to A[i].

After this process, we have some array B.

Return the smallest possible difference between the maximum value of B and the minimum value of B.


```
Example 1:

Input: A = [1], K = 0
Output: 0
Explanation: B = [1]
Example 2:

Input: A = [0,10], K = 2
Output: 6
Explanation: B = [2,8]
Example 3:

Input: A = [1,3,6], K = 3
Output: 0
Explanation: B = [3,3,3] or B = [4,4,4]
```


## Java Solution:

```java
class Solution {
    public int smallestRangeI(int[] A, int K) {
        if(A.length <= 1)
            return 0;
        int size = A.length;
        int[] tmpArray = A;

        int min = tmpArray[0];
        int max = tmpArray[0];
        for(int i = 1;i < size;i++){
            if(min > tmpArray[i])
                min = tmpArray[i];
            if(max < tmpArray[i])
                max = tmpArray[i];
        }

        if(min + K >= max - K){
            return 0;
        }
        else{
            return max - min - 2 * K;
        }
    }

}
```

