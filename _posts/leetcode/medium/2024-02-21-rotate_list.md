---
layout:     post
title:      "Rotate List"
summary:    "\"default\""
date:       2024-02-21 11:09:58
author:     "Bill"
header-img: img/bill/header-posts/2024-01-24-header.png
catalog: true
stickie: false
hide: true
life: false
guitartab: false
tags:
    - default
---

# Rotate List

Given the head of a linked list, rotate the list to the right by k places.

```
Example 1:


Input: head = [1,2,3,4,5], k = 2
Output: [4,5,1,2,3]
Example 2:


Input: head = [0,1,2], k = 4
Output: [2,0,1]
```


# Solution

```c++
class Solution {
  public:
  ListNode* rotateRight(ListNode* head, int k) {
    if (head == nullptr) {
      return nullptr;
    }
    int i = 0;
    ListNode* p = head;
    ListNode* fixHead = head;
    int size = 0;
    ListNode* sizePtr = head;
    while (sizePtr) {
      size++;
      sizePtr = sizePtr->next;
    }
    k = k % size;
    while (i < k) {
      while (p->next != nullptr && p->next->next != nullptr) {
        p = p->next;
      }
      ListNode* prevNode = p;
      ListNode* tailNode = p->next;
      if (tailNode == nullptr) {
        return fixHead;
      }
      p->next = nullptr;
      tailNode->next = fixHead;
      p = tailNode;
      fixHead = p;
      i++;
    }
    return fixHead;
  }
};
```
