---
layout:     post
title:      "N-Repeated Element in Size 2N Array"
summary:    "\"在长度 2N 的数组中找出重复 N 次的元素\""
date:       2023-03-11 15:46:23
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

# N-Repeated Element in Size 2N Array

In a array A of size 2N, there are N+1 unique elements, and exactly one of these elements is repeated N times.

Return the element repeated N times.

```
Example 1:

Input: [1,2,3,3]
Output: 3

Example 2:

Input: [2,1,2,5,3,2]
Output: 2

Example 3:

Input: [5,1,5,2,5,3,5,4]
Output: 5



Note:

    4 <= A.length <= 10000
    0 <= A[i] < 10000
    A.length is even
```


## Java Solution:

```java
import java.util.HashMap;
import java.util.Map;

/**
 * Created by bill on 2/18/19.
 */
public class Solution {
    Map<Integer, Integer> myMap = new HashMap();
    public int repeatedNTimes(int[] A) {
        int N = A.length/2;
        for (int ele: A) {
            int tmp = 0;
            if(!myMap.containsKey(ele)){
                myMap.put(ele,1);
            }
            else{
                tmp = myMap.get(ele) + 1;
                myMap.replace(ele,tmp);
            }
            if(tmp == N){ return ele;}
        }
        return -1;
    }

    public static void main(String[] args) {
        Solution mySolution = new Solution();
        int [] array = {2,1,2,5,3,2};
        int ret = mySolution.repeatedNTimes(array);
        System.out.println(ret);
    }
}
```

