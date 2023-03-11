---
layout:     post
title:      "Add Two Numbers"
summary:    "两数相加"
date:       2023-03-11 10:06:26
author:     "Bill"
header-img: "img/bill/header-posts/2023-03-11-header.jpg"
catalog: true
hide: true
tags:
    - default
---

# Add Two Numbers

You are given two non-empty linked lists representing two non-negative integers. The digits are stored in reverse order, and each of their nodes contains a single digit. Add the two numbers and return the sum as a linked list.

You may assume the two numbers do not contain any leading zero, except the number 0 itself.

```
Example 1:
Input: l1 = [2,4,3], l2 = [5,6,4]
Output: [7,0,8]
Explanation: 342 + 465 = 807.

Example 2:
Input: l1 = [0], l2 = [0]
Output: [0]

Example 3:
Input: l1 = [9,9,9,9,9,9,9], l2 = [9,9,9,9]
Output: [8,9,9,9,0,0,0,1]

Constraints:

The number of nodes in each linked list is in the range [1, 100].
0 <= Node.val <= 9
It is guaranteed that the list represents a number that does not have leading zeros.
```

## C++ Solution

考虑到要验证比较麻烦，先把测试架构实现好, 然后再实现主要逻辑。主要思路就是分别遍历链表，一旦有链表到头了，也不能停止，直到分别指向两个链表的指针都为空，且进位也不为1时，才能够停止整个流程。

```c++
// c++
#include<iostream>
#include<vector>
using namespace std;
struct ListNode {
  int val;
  ListNode *next;
  ListNode() : val(0), next(nullptr) {}
  ListNode(int x) : val(x), next(nullptr) {}
  ListNode(int x, ListNode *next) : val(x), next(next) {}
};

ListNode* constructLists(vector<int>src) {
  ListNode* head = nullptr;
  ListNode* prev = nullptr;
  for (auto val : src) {
    ListNode *current = new ListNode(val);
    if (prev != nullptr) {
      prev->next = current;
    } else {
      head = current;
    }
    prev = current;
  }
  return head;
}

class Solution {
  public:
    Solution() {}
    ListNode* addTwoNumbers(ListNode* l1, ListNode* l2) {
      ListNode *ptr1 = l1;
      ListNode *ptr2 = l2;
      ListNode* head = nullptr;
      ListNode* prev = nullptr;
      int carry = 0;
      int sum = 0;
      while (ptr1 != nullptr || ptr2 != nullptr || carry != 0) {
        sum = (ptr1 != nullptr ? ptr1->val : 0) +
          (ptr2 != nullptr ? ptr2->val : 0) + carry;
        carry = sum / 10;
        int val = sum % 10;
        ListNode *current = new ListNode(val);
        if (prev != nullptr) {
          prev->next = current;
        } else {
          head = current;
        }
        prev = current;
        if (ptr1 != nullptr) {
          ptr1 = ptr1->next;
        }
        if (ptr2 != nullptr) {
          ptr2 = ptr2->next;
        }
      }
      return head;
    }
};


void test(vector<int> vec1, vector<int> vec2, vector<int>target) {
  ListNode *list1 = constructLists(vec1);
  ListNode *list2 = constructLists(vec2);
  Solution *ptr = new Solution();
  ListNode *ans = ptr->addTwoNumbers(list1, list2);
  ListNode *expect = constructLists(target);

  int ansSize = 0;
  ListNode *sizeAnsPtr = ans;
  while (sizeAnsPtr != nullptr) {
    ansSize++;
    sizeAnsPtr = sizeAnsPtr->next;
  }
  if (ansSize != target.size()) {
    cout<<"size not matched! expect "<<target.size()<< " real size is "<<ansSize<<endl;
    return;
  }

  ListNode *ansPtr = ans;
  ListNode *expectPtr = expect;
  bool testRet = true;
  while (ansPtr != nullptr && expectPtr != nullptr) {
    if (ansPtr->val != expectPtr->val) {
      testRet = false;
      break;
    }
    ansPtr = ansPtr->next;
    expectPtr = expectPtr->next;
  }
  if (testRet) {
    cout<<"test passed!"<<endl;
  } else {
    cout<<"test failed!"<<endl;
  }
}

int main() {
  test(vector<int>{2,4,3}, vector<int>{5,6,4}, vector<int>{7,0,8});
  test(vector<int>{0}, vector<int>{0}, vector<int>{0});
  test(vector<int>{9,9,9,9,9,9,9}, vector<int>{9,9,9,9}, vector<int>{8,9,9,9,0,0,0,1});
}
```


