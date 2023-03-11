---
layout:     post
title:      "Shortest Distance to a Character"
summary:    "\"字符的最短距离\""
date:       2023-03-11 15:21:20
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

# Shortest Distance to a Character

Given a string S and a character C, return an array of integers representing the shortest distance from the character C in the string.

```
Example 1:

Input: S = "loveleetcode", C = 'e'
Output: [3, 2, 1, 0, 1, 0, 0, 1, 2, 2, 1, 0]
```

Note:

- S string length is in [1, 10000].
- C is a single character, and guaranteed to be in string S.
All letters in S and C are lowercase.

## Java Solution:

```java
class Solution {
    public int[] shortestToChar(String S, char C) {
		Queue<Integer> mQueue = new LinkedList<>();
		int [] ret = new int[S.length()];
		for (int i = 0; i < S.length();i++) {
			if(S.charAt(i) == C){
				mQueue.add(i);
			}
		}

		for (int i = 0; i < S.length();i++) {
			int min = S.length();
			for (int ele: mQueue) {
				int distance = Math.abs(ele - i);
				if(min > distance){
					min = distance;
				}
			}
			ret[i] = min;
		}
		return ret;
	}
}
```


