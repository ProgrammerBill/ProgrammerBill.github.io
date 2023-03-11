---
layout:     post
title:      "Univalued Binary Tree"
summary:    "\"单值二叉树\""
date:       2023-03-11 15:48:30
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

# Univalued Binary Tree


A binary tree is univalued if every node in the tree has the same value.

Return true if and only if the given tree is univalued.


- Input: [1,1,1,1,1,null,1]
- Output: true



- Input: [2,2,2,5,2]
- Output: false




## Java Solution:

```java
public class Solution {
    public boolean isUnivalTree(TreeNode root) {
        int val = root.val;
        if(root.left == null && root.right == null){
            return true;
        }
        if(root.left == null){
            return isUnivalTree(root.right) &&(root.val == root.right.val);
        }
        else if(root.right == null){
            return isUnivalTree(root.left) &&(root.val == root.left.val);
        }
        else{
            return isUnivalTree(root.left) && isUnivalTree(root.right)
                    && (root.val == root.left.val) && (root.val == root.right.val);
        }
    }
}
```

