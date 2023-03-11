---
layout:     post
title:      "Flipping an Image"
summary:    "\"翻转图像\""
date:       2023-03-11 15:23:33
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

# Flipping an Image

Given a binary matrix A, we want to flip the image horizontally, then invert it, and return the resulting image.

To flip an image horizontally means that each row of the image is reversed.  For example, flipping [1, 1, 0] horizontally results in [0, 1, 1].

To invert an image means that each 0 is replaced by 1, and each 1 is replaced by 0. For example, inverting [0, 1, 1] results in [1, 0, 0].

```
Example 1:

Input: [[1,1,0],[1,0,1],[0,0,0]]
Output: [[1,0,0],[0,1,0],[1,1,1]]
Explanation: First reverse each row: [[0,1,1],[1,0,1],[0,0,0]].
Then, invert the image: [[1,0,0],[0,1,0],[1,1,1]]
Example 2:

Input: [[1,1,0,0],[1,0,0,1],[0,1,1,1],[1,0,1,0]]
Output: [[1,1,0,0],[0,1,1,0],[0,0,0,1],[1,0,1,0]]
Explanation: First reverse each row: [[0,0,1,1],[1,0,0,1],[1,1,1,0],[0,1,0,1]].
Then invert the image: [[1,1,0,0],[0,1,1,0],[0,0,0,1],[1,0,1,0]]

Notes:

- 1 <= A.length = A[0].length <= 20
- 0 <= A[i][j] <= 1
```


## Java Solution:

```java
class Solution {
     public int[][] flipAndInvertImage(int[][] A) {
        for(int i = 0; i < A[0].length; i++){
            A[i] = reverseRow(A[i]);
            A[i] = invertRow(A[i]);
        }
        return A;
    }

    public int[] reverseRow(int[] input){
        if(input.length <= 1) return input;
        int head = 0;
        int tail = input.length - 1;
        while(head < tail){
            int tmp = input[head];
            input[head] = input[tail];
            input[tail] = tmp;
            tail--;
            head++;
        }
        return input;
    }

    public int[] invertRow(int[] input){
        if(input.length < 1) return input;
        for(int i = 0; i < input.length; i++){
            input[i] ^= 1;
        }
        return input;
    }

}
```

