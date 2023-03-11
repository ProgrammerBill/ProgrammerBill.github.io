---
layout:     post
title:      "Range Sum of BST"
summary:    "\"二叉搜索树的范围和\""
date:       2023-03-11 15:40:51
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

# Range Sum of BST

Given the root node of a binary search tree, return the sum of values of all nodes with value between L and R (inclusive).

The binary search tree is guaranteed to have unique values.


```
Example 1:

Input: root = [10,5,15,3,7,null,18], L = 7, R = 15
Output: 32
Example 2:

Input: root = [10,5,15,3,7,13,18,1,null,6], L = 6, R = 10
Output: 23
```


## Java Solution

```java
/**
 * Definition for a binary tree node.
 * public class TreeNode {
 *     int val;
 *     TreeNode left;
 *     TreeNode right;
 *     TreeNode(int x) { val = x; }
 * }
 */
class Solution {
    public int sum;
    public Solution(){
        sum = 0;
    }
    public int rangeSumBST(TreeNode root, int L, int R) {
        DFS(root, L, R);
        return sum;
    }

    public void DFS(TreeNode root, int L, int R){
        if(root != null){
            if(root.val >= L && root.val <= R){
                sum+=root.val;
            }
            if(root.val > L){
                DFS(root.left, L, R);
            }
            if(root.val < R){
                DFS(root.right, L, R);
            }
        }
    }
}
```

