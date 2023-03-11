---
layout:     post
title:      "Convert Sorted Array to Binary Search Tree"
summary:    "\"将有序数组转换为二叉搜索树\""
date:       2023-03-11 13:30:54
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

# Convert Sorted Array to Binary Search Tree

Given an integer array nums where the elements are sorted in ascending order, convert it to a height-balanced binary search tree.


Example 1
Input: nums = [-10,-3,0,5,9]
Output: [0,-3,9,-10,null,5]
Explanation: [0,-10,5,null,-3,null,9] is also accepted:

Example 2:
Input: nums = [1,3]
Output: [3,1]
Explanation: [1,null,3] and [3,1] are both height-balanced BSTs.

## C++ Solution

```c++
    TreeNode* sortedArrayToBST(vector<int>& nums) {
        if (nums.empty()) {return nullptr;}
        int idx = nums.size() / 2;
        TreeNode* root = new TreeNode(nums[idx]);
        vector<int>leftNums, rightNums;
        for (int i = 0; i < idx; i++) {
            leftNums.push_back(nums[i]);
        }
        for (int i = idx + 1; i < nums.size(); i++)
        {
            rightNums.push_back(nums[i]);
        }

        root->left = sortedArrayToBST(leftNums);
        root->right = sortedArrayToBST(rightNums);
        return root;
    }
```


