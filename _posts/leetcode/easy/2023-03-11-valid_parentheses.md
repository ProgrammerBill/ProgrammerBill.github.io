---
layout:     post
title:      "Valid Parentheses"
summary:    "\"有效的括号\""
date:       2023-03-11 13:07:09
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

# Valid Parentheses

Given a string s containing just the characters '(', ')', '{', '}', '[' and ']', determine if the input string is valid.

An input string is valid if:

Open brackets must be closed by the same type of brackets.
Open brackets must be closed in the correct order.
Every close bracket has a corresponding open bracket of the same type.

```
Example 1:

Input: s = "()"
Output: true
Example 2:

Input: s = "()[]{}"
Output: true
Example 3:

Input: s = "(]"
Output: false
```

## C++ solution

```c++
bool isValid(string s){
   stack<char> parentheses;
   for (auto character : s) {
     switch(character){
       case '(' :
       case '[' :
       case '{' :
         parentheses.push(character);
         break;
      case ')':
         if (parentheses.empty() || parentheses.top() != '(') {
            return false;
         }
         if (!parentheses.empty()) {
           parentheses.pop();
         }
         break;
      case ']':
         if (parentheses.empty() || parentheses.top() != '[') {
            return false;
         }
         if (!parentheses.empty()) {
           parentheses.pop();
         }
         break;
      case '}':
         if (parentheses.empty() || parentheses.top() != '{') {
            return false;
         }
         if (!parentheses.empty()) {
           parentheses.pop();
         }
         break;
     }
   }
   return parentheses.empty();
}

```


