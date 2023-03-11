---
layout:     post
title:      "Merge Two Sorted Lists"
summary:    "\"合并两个有序链表\""
date:       2023-03-11 13:10:20
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

# Merge Two Sorted Lists

You are given the heads of two sorted linked lists list1 and list2.

Merge the two lists in a one sorted list. The list should be made by splicing together the nodes of the first two lists.

Return the head of the merged linked list.

![](/img/bill/in-posts//)

```
Example 1:
Input: list1 = [1,2,4], list2 = [1,3,4]
Output: [1,1,2,3,4,4]
Example 2:

Input: list1 = [], list2 = []
Output: []
Example 3:

Input: list1 = [], list2 = [0]
Output: [0]
```

## C++ Solution

```c++
ListNode* mergeTwoLists(ListNode* list1, ListNode* list2) {
  if (list1 == nullptr) {
    return list2;
  } else if (list2 == nullptr) {
    return list1;
  }
  ListNode* head;
  if (list1->val <= list2->val) {
    head = list1;
    head->next = mergeTwoLists(list1->next, list2);
  } else {
    head = list2;
    head->next = mergeTwoLists(list1, list2->next);
  }
  return head;
}
```

