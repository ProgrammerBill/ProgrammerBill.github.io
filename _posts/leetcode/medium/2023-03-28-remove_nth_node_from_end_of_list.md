---
layout:     post
title:      "Remove Nth Node From End of List"
summary:    "\"删除链表的倒数第 N 个结点\""
date:       2023-03-28 09:55:50
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

# 19. Remove Nth Node From End of List

Given the head of a linked list, remove the nth node from the end of the list and return its head.



```
Input: head = [1,2,3,4,5], n = 2
Output: [1,2,3,5]
Example 2:

Input: head = [1], n = 1
Output: []
Example 3:

Input: head = [1,2], n = 1
Output: [1]
```

# C++ Solution

```c++
ListNode* removeNthFromEnd(ListNode* head, int n) {
  ListNode* ptr = head;
  int len = 0;
  while (ptr != nullptr) {
    len++;
    ptr = ptr->next;
  }
  int index = len - n - 1;
  ListNode *guard = new ListNode();
  guard->next = head;
  ptr = guard;
  int i = -1;
  while (i < index) {
    ptr = ptr->next;
    i++;
  }
  auto removeNode = ptr->next;
  if (removeNode != nullptr) {
    ptr->next = removeNode->next;
  }
  return guard->next;
}
```
