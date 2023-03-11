---
layout:     post
title:      "Remove Duplicates from Sorted List"
summary:    "\"删除排序链表中的重复元素\""
date:       2023-03-11 13:26:46
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

# Remove Duplicates from Sorted List

Given the head of a sorted linked list, delete all duplicates such that each element appears only once. Return the linked list sorted as well.

Example 1:
Input: head = [1,1,2]
Output: [1,2]

Example 2:
Input: head = [1,1,2,3,3]
Output: [1,2,3]

## C++ Solution

```c++
ListNode* deleteDuplicates(ListNode* head) {
  ListNode *ret = head;
  ListNode *last = nullptr;
  ListNode *cur = head;
  set<int> mySet;
  while (cur != nullptr) {
    if (mySet.count(cur->val) == 0) {
      mySet.insert(cur->val);
      last = cur;
      cur = cur->next;
    } else {
      cur = cur->next;
      last->next = cur;
    }
  }
  return ret;
}
```


