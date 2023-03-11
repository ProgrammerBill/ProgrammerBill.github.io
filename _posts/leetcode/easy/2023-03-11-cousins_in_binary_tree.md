---
layout:     post
title:      "Cousins in Binary Tree"
summary:    "\"二叉树的堂兄弟节点\""
date:       2023-03-11 15:56:31
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

# Cousins in Binary Tree


In a binary tree, the root node is at depth 0, and children of each depth k node are at depth k+1.

Two nodes of a binary tree are cousins if they have the same depth, but have different parents.

We are given the root of a binary tree with unique values, and the values x and y of two different nodes in the tree.

Return true if and only if the nodes corresponding to the values x and y are cousins.



Example 1:

![](/img/bill/in-posts//)

```
Input: root = [1,2,3,4], x = 4, y = 3
Output: false
```

Example 2:

![](/img/bill/in-posts//)

```
Input: root = [1,2,3,null,4,null,5], x = 5, y = 4
Output: true
```

Example 3:

![](/img/bill/in-posts//)


```
Input: root = [1,2,3,null,4], x = 2, y = 3
Output: false
```

Note:

The number of nodes in the tree will be between 2 and 100.
Each node has a unique integer value from 1 to 100.

## Java Solution:

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
    public boolean isCousins(TreeNode root, int x, int y) {
        TreeNode ParentFirst = getParentWithChild(root, x);
        TreeNode ParentSecond = getParentWithChild(root, y);

        if(ParentFirst == null || ParentSecond == null){
            return false;
        }

        if((ParentFirst.val != ParentSecond.val) &&
                getDepth(root,ParentFirst) == getDepth(root,ParentSecond)){
            return true;
        }
        else{
            return false;
        }
    }

    int getDepth(TreeNode root,TreeNode target){
        if(root == null){
            return -1;
        }
        if(root.val == target.val){
            return 0;
        }
        int leftDepth = getDepth(root.left,target);
        int righttDepth = getDepth(root.right,target);
        if(leftDepth != -1){
            return leftDepth + 1;
        }
        if(righttDepth != -1){
            return righttDepth + 1;
        }
        return -1;
    }


    TreeNode getParentWithChild(TreeNode root, int x){
        if(root == null){ return null;}
        if((root.left != null && root.left.val == x) ||
                (root.right!= null && root.right.val == x)){
            return root;
        }
        TreeNode left = getParentWithChild(root.left,x);
        TreeNode right = getParentWithChild(root.right,x);
        if(left != null){
            return left;
        }
        if(right != null){
            return right;
        }
        return null;
    }
}
```

