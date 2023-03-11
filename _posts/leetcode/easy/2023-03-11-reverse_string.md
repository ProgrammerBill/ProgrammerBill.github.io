---
layout:     post
title:      "Reverse String"
summary:    "\"反转字符串\""
date:       2023-03-11 13:44:19
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

# Reverse String


Write a function that reverses a string. The input string is given as an array of characters char[].

Do not allocate extra space for another array, you must do this by modifying the input array in-place with O(1) extra memory.

You may assume all the characters consist of printable ascii characters.


```
Example 1:

Input: ["h","e","l","l","o"]
Output: ["o","l","l","e","h"]
Example 2:

Input: ["H","a","n","n","a","h"]
Output: ["h","a","n","n","a","H"]
```
## Java Solution

Solution:

```java
class Solution {
    public void reverseString(char[] s) {
		int head = 0;
		int tail = s.length - 1;
		while(head < tail){
			char tmp = s[head];
			s[head] = s[tail];
			s[tail] = tmp;
			head++;
			tail--;
		}
	}
}
```


