---
layout:     post
title:      "Add Binary"
summary:    "\"二进制求和\""
date:       2023-03-11 13:23:42
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

# Add Binary

Given two binary strings a and b, return their sum as a binary string.

```
 Example 1:

 Input: a = "11", b = "1"
 Output: "100"
 Example 2:

 Input: a = "1010", b = "1011"
 Output: "10101"
```

## C++ Solution

```c++
string addBinary(string a, string b) {
    int carry = 0;
    auto a_iter = a.rbegin();
    auto b_iter = b.rbegin();
    stack<char> myStack;
    while (a_iter != a.rend() || b_iter != b.rend() || carry != 0) {
        int val = 0;
        if (a_iter != a.rend() && b_iter != b.rend()) {
            val = (*a_iter - '0') + (*b_iter - '0') + carry;
        } else if (a_iter != a.rend() && b_iter == b.rend()) {
            val = (*a_iter - '0')  + carry;
        } else if (a_iter == a.rend() && b_iter != b.rend()) {
            val = (*b_iter - '0')  + carry;
        } else {
            val = carry;
        }
        carry = val / 2;
        myStack.push(val % 2 + '0');
        if (a_iter != a.rend()) {
            a_iter++;
        }
        if (b_iter != b.rend()) {
            b_iter++;
        }
    }
    string ret;
    while (!myStack.empty()) {
        ret.push_back(myStack.top());
        myStack.pop();
    }
    return ret;
}
```

