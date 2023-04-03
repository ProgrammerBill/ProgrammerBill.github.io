---
layout:     post
title:      "Merge k Sorted Lists"
summary:    "\"合并 K 个升序链表\""
date:       2023-04-03 10:45:30
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

# 23. Merge k Sorted Lists

You are given an array of k linked-lists lists, each linked-list is sorted in ascending order.

Merge all the linked-lists into one sorted linked-list and return it.

```
Example 1:

Input: lists = [[1,4,5],[1,3,4],[2,6]]
Output: [1,1,2,3,4,4,5,6]
Explanation: The linked-lists are:
[
  1->4->5,
  1->3->4,
  2->6
]
merging them into one sorted list:
1->1->2->3->4->4->5->6
Example 2:

Input: lists = []
Output: []
Example 3:

Input: lists = [[]]
Output: []
```

# C++ Solution

```c++

ListNode *mergeKLists(vector<ListNode *> &lists) {
      set<ListNode *> heads;
      vector<ListNode *> sorted;
      ListNode *merged = new ListNode();
      ListNode *mergedHead = merged;

      for (auto list : lists) {
        heads.insert(list);
      }

      while (heads.size() > 0) {
        ListNode *currentHead = nullptr;
        int minVal = INT_MAX;
        for (auto head : heads) {
          if (head != nullptr && head->val < minVal) {
            minVal = head->val;
            currentHead = head;
          }
      }
      sorted.push_back(currentHead);
      merged->next = currentHead;
      merged = merged->next;
      heads.erase(currentHead);
      if (currentHead != nullptr &&currentHead->next != nullptr) {
        heads.insert(currentHead->next);
      }
    }
    return mergedHead->next;
  }

```
