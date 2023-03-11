---
layout:     post
title:      "Binary Tree Inorder Traversal"
summary:    "\"二叉树的中序遍历\""
date:       2023-03-11 13:28:45
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


# Binary Tree Inorder Traversal

Given the root of a binary tree, return the inorder traversal of its nodes' values.
Example 1:


Input: root = [1,null,2,3]
Output: [1,3,2]
Example 2:

Input: root = []
Output: []
Example 3:

Input: root = [1]
Output: [1]

## C++ Solution

递归实现：

```c++
vector<int> inorderTraversal(TreeNode* root) {
    vector<int>ret;
    inorder(root, ret);
    return ret;
}
void inorder(TreeNode* root, vector<int>&v){
    if (root != nullptr) {
        inorder(root->left, v);
        v.push_back(root->val);
        inorder(root->right, v);
    }
}
```

## C++ Solution

迭代实现:

```c++
   vector<int> inorderTraversal(TreeNode* root) {
        vector<int> myVec;
        TreeNode* cur = root;
        stack<TreeNode *> myStack;
        while (cur != nullptr || !myStack.empty()) {
            while (cur != nullptr) {
                myStack.push(cur);
                cur = cur->left;
            }
            TreeNode *top = myStack.top();
            myVec.push_back(top->val);
            myStack.pop();
            if (top->right != nullptr) {
                cur = top->right;
            }
        }
        return myVec;
    }
```


