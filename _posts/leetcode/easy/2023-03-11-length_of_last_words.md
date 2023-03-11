---
layout:     post
title:      "Length Of Last words"
summary:    "\"最后一个单词的长度\""
date:       2023-03-11 13:20:26
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

# Length Of Last words

Given a string s consisting of words and spaces, return the length of the last word in the string.

A word is a maximal substring consisting of non-space characters only.

```

 Example 1:

 Input: s = "Hello World"
 Output: 5
 Explanation: The last word is "World" with length 5.
 Example 2:

 Input: s = "   fly me   to   the moon  "
 Output: 4
 Explanation: The last word is "moon" with length 4.
 Example 3:

 Input: s = "luffy is still joyboy"
 Output: 6
 Explanation: The last word is "joyboy" with length 6.
```

## C++ Solution

```c++
int lengthOfLastWord(string s) {
    auto riter = s.rbegin();
    while (riter != s.rend()) {
        if (isspace(*riter)) {
            riter++;
            continue;
        } else {
            break;
        }
    }
    int length = 0;
    while (riter != s.rend()) {
        if (!isspace(*riter)) {
            length++;
            riter++;
        } else {
            break;
        }
    }
    return length;
}
```

