---
layout:     post
title:      "Swap Nodes in Pairs"
summary:    "\"两两交换链表中的节点\""
date:       2023-04-04 10:32:13
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

# 24. Swap Nodes in Pairs

Given a linked list, swap every two adjacent nodes and return its head. You must solve the problem without modifying the values in the list's nodes (i.e., only nodes themselves may be changed.)

```
Example 1:


Input: head = [1,2,3,4]
Output: [2,1,4,3]
Example 2:

Input: head = []
Output: []
Example 3:

Input: head = [1]
Output: [1]
```

# C++ Solution


```c++
class Solution {
  public:
  ListNode *swapPairs(ListNode *head) {
    if (head == nullptr || head->next == nullptr) {
      return head;
    }
    ListNode *left = head;
    ListNode *right = head->next;
    ListNode *origin = right;
    ListNode *lastNode = nullptr;
    while (right != nullptr) {
      //1. swap right and left
      left->next = right->next;
      right->next = left;
      if (lastNode != nullptr) {
        lastNode->next = right;
      }
      lastNode = left;
      //2. set the new right and left
      left = left->next;
      if (left != nullptr) {
        right = left->next;
      } else {
        right = nullptr;
      }
    }
    return origin;
  }
};


```
