---
layout:     post
title:      "Number Complement"
summary:    "\"数字的补数\""
date:       2023-03-11 14:15:38
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

# Number Complement

Given a positive integer, output its complement number. The complement strategy is to flip the bits of its binary representation.

Note:
The given integer is guaranteed to fit within the range of a 32-bit signed integer.
You could assume no leading zero bit in the integer’s binary representation.

```
Example 1:
Input: 5
Output: 2
Explanation: The binary representation of 5 is 101 (no leading zero bits), and its complement is 010. So you need to output 2.
Example 2:
Input: 1
Output: 0
Explanation: The binary representation of 1 is 1 (no leading zero bits), and its complement is 0. So you need to output 0.
```

## Java Solution:

```java
class Solution {
    public int findComplement(int num) {
        int divisor = num;
        Stack<Integer>mStack = new Stack<>();
        while(divisor != 1){
            int remainder = divisor % 2;
            divisor /= 2;
            remainder = remainder == 1 ? 0 : 1;
            mStack.push(remainder);
        }
        mStack.push(0);
        int sum = 0;
        while(!mStack.isEmpty()){
            sum = sum * 2 + mStack.pop();
        }


        return sum;
    }
}
```


