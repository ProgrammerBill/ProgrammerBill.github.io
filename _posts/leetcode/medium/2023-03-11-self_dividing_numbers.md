---
layout:     post
title:      "Self Dividing Numbers"
summary:    "\"自除数\""
date:       2023-03-11 14:50:36
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

# Self Dividing Numbers

A self-dividing number is a number that is divisible by every digit it contains.

For example, 128 is a self-dividing number because 128 % 1 == 0, 128 % 2 == 0, and 128 % 8 == 0.

Also, a self-dividing number is not allowed to contain the digit zero.

Given a lower and upper number bound, output a list of every possible self dividing number, including the bounds if possible.

Example 1:
Input:
left = 1, right = 22
Output: [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 15, 22]
Note:

The boundaries of each input argument are 1 <= left <= right <= 10000.


## Java Solution:

```java
class Solution {
    public List<Integer> selfDividingNumbers(int left, int right) {
        List<Integer> myList = new LinkedList<>();
        for(int i = left;i <= right; i++){
            int copy = i;
            boolean isSelfDividing = true;
            while(copy != 0 ){
                int dividend = copy % 10;
                copy = copy / 10;
                if(dividend == 0 || i % dividend != 0){
                    isSelfDividing = false;
                    break;
                }
            }
            if(isSelfDividing)
                myList.add(i);
        }

        return myList;
    }
}
```

