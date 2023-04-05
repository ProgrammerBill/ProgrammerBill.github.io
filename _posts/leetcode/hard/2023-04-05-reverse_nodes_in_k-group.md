---
layout:     post
title:      "Reverse Nodes in k-Group"
summary:    "\"K 个一组翻转链表\""
date:       2023-04-05 14:51:57
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



# Reverse Nodes in k-Group

Given the head of a linked list, reverse the nodes of the list k at a time, and return the modified list.

k is a positive integer and is less than or equal to the length of the linked list. If the number of nodes is not a multiple of k then left-out nodes, in the end, should remain as it is.

You may not alter the values in the list's nodes, only nodes themselves may be changed.

```
Example 1:


Input: head = [1,2,3,4,5], k = 2
Output: [2,1,4,3,5]

Example 2:

Input: head = [1,2,3,4,5], k = 3
Output: [3,2,1,4,5]
```

# C++ Solution


```c++
class Solution {
  public:
  // return reverse HeadNode and tailHead
  pair<ListNode*, ListNode*> reverse(ListNode* head, ListNode* tailHead) {
    if (head == tailHead) {
      return {tailHead, head};
    }
    ListNode* curHead = head;
    ListNode* nextHead;
    ListNode* preHead = nullptr;
    tailHead->next = nullptr;
    while (curHead != nullptr && curHead != tailHead) {
      nextHead = curHead->next;
      ListNode* newHead = nullptr;
      if (nextHead != nullptr) {
        newHead = nextHead->next;
        nextHead->next = curHead;
      }
      curHead->next = preHead;
      preHead = nextHead;
      curHead = newHead;
    }
    if (curHead != nullptr) {
      curHead->next = preHead;
    }
    return {tailHead, head};
  }

  ListNode* reverseKGroup(ListNode* head, int k) {
    if (head == nullptr) {
      return head;
    }
    ListNode* originHead = new ListNode();
    originHead->next = head;
    ListNode* preHead;
    preHead = originHead;
    ListNode* curHead = head;
    ListNode* tailHead;
    while (curHead != nullptr) {
      tailHead = curHead;
      for (int i = 0; i < k - 1; i++) {
        tailHead = tailHead->next;
        if (tailHead == nullptr) {
          return originHead->next;
        }
      }
      ListNode* nextNewHead = tailHead->next;
      auto lists = reverse(curHead, tailHead);
      preHead->next = lists.first;
      preHead = lists.second;
      preHead->next = nextNewHead;
      curHead = nextNewHead;
    }
    return originHead->next;
  }
};
```

