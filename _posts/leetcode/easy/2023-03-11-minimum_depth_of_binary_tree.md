---
layout:     post
title:      "Minimum Depth of Binary Tree"
summary:    "\"二叉树的最小深度\""
date:       2023-03-11 13:34:55
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

# Minimum Depth of Binary Tree

Given a binary tree, find its minimum depth.

The minimum depth is the number of nodes along the shortest path from the root node down to the nearest leaf node.

Note: A leaf is a node with no children.

Example 1:
Input: root = [3,9,20,null,null,15,7]
Output: 2

Example 2:
Input: root = [2,null,3,null,4,null,5,null,6]
Output: 5

## C++ Solution

```c++
    int minDepth(TreeNode* root) {
        if (root == nullptr) {
            return 0;
        }
        int left = minDepth(root->left);
        int right = minDepth(root->right);
        if (root->left == nullptr) {
            return 1 + right;
        } else if (root->right == nullptr) {
            return 1 + left;
        } else {
            return min(left, right) + 1;
        }
    }
```


