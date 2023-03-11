---
layout:     post
title:      "Groups of Special-Equivalent Strings"
summary:    "\"特殊等价字符串组\""
date:       2023-03-11 15:25:43
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

# Groups of Special-Equivalent Strings


You are given an array A of strings.

Two strings S and T are special-equivalent if after any number of moves, S == T.

A move consists of choosing two indices i and j with i % 2 == j % 2, and swapping S[i] with S[j].

Now, a group of special-equivalent strings from A is a non-empty subset S of A such that any string not in S is not special-equivalent with any string in S.

Return the number of groups of special-equivalent strings from A.


```
Example 1:

Input: ["a","b","c","a","c","c"]
Output: 3
Explanation: 3 groups ["a","a"], ["b"], ["c","c","c"]
Example 2:

Input: ["aa","bb","ab","ba"]
Output: 4
Explanation: 4 groups ["aa"], ["bb"], ["ab"], ["ba"]
Example 4:

Input: ["abc","acb","bac","bca","cab","cba"]
Output: 3
Explanation: 3 groups ["abc","cba"], ["acb","bca"], ["bac","cab"]
Example 4:

Input: ["abcd","cdab","adcb","cbad"]
Output: 1
Explanation: 1 group ["abcd","cdab","adcb","cbad"]
```

## Java Solution:

```java

class Solution {
    public int numSpecialEquivGroups(String[] A) {
        Set<String> seen = new HashSet();
        for (String S: A) {
            int[] count = new int[52];
            for (int i = 0; i < S.length(); ++i)
                count[S.charAt(i) - 'a' + 26 * (i % 2)]++;
            seen.add(Arrays.toString(count));
        }
        return seen.size();
    }
}

```

- What does S.charAt(i) - 'a' do?
The character a is 97 in ASCII. By subtracting a from another letter in the alphabet, we can convert the ASCII to represent a as 0 instead - thereby making the alphabet 0-indexed.
- What does 26 * (i % 2) do?
There are 26 letters in the alphabet
i % 2 returns 0 if even and 1 if odd
26 * (i % 2) returns 0 if even and 26 if odd
S.charAt(i) - a <— this brings the letter to be 0-indexed
- Where did 52 come from in int[] count = new int[52] ?
There are 26 letters in the alphabet
A letter could be in an odd index or an even index. This makes 26 + 26 = 52 "kind of letters"
The index of the count array represents the property of the letter --> 1. the value of the letter and 2. if it is odd of even
If the string has two letter 'a's and both of the letters are at an even index, then count[26] == 2.


