---
layout:     post
title:      "Permutation Sequence"
summary:    "\"default\""
date:       2024-02-20 15:24:19
author:     "Bill"
header-img: "img/bill/header-posts/2024-02-20-header.jpg"
catalog: true
stickie: false
hide: true
life: false
guitartab: false
tags:
    - default
---


# Permutation Sequence

The set [1, 2, 3, ..., n] contains a total of n! unique permutations.

By listing and labeling all of the permutations in order, we get the following sequence for n = 3:

"123"
"132"
"213"
"231"
"312"
"321"
Given n and k, return the kth permutation sequence.

```
Example 1:

Input: n = 3, k = 3
Output: "213"
Example 2:

Input: n = 4, k = 9
Output: "2314"
Example 3:

Input: n = 3, k = 1
Output: "123"
```

# Solution

```c++
class Solution {
  public:
  string getPermutation(int n, int k) {
    if (n == 1) {
      return "1";
    }
    string ret;
    int fact[n - 1];
    vector<int> s;
    for (int i = 1; i <= n; i++) {
      s.push_back(i);
    }
    fact[0] = 1;
    for (int i = 1; i < n - 1; i++) {
      fact[i] = (i + 1) * fact[i - 1];
    }
    int j = 1;
    while (j <= n - 1) {
      int index = (k - 1) / fact[n - 1 - j];
      ret += to_string(*(s.begin() + index));
      s.erase(s.begin() + index);
      k = k - index * fact[n - 1 - j];
      j++;
    }
    ret.append(to_string(s[0]));
    return ret;
  }
};
```

