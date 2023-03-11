---
layout:     post
title:      "Trim a Binary Search Tree"
summary:    "\"修剪二叉搜索树\""
date:       2023-03-11 14:43:44
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

# Trim a Binary Search Tree


Given a binary search tree and the lowest and highest boundaries as L and R, trim the tree so that all its elements lies in [L, R] (R >= L). You might need to change the root of the tree, so the result should return the new root of the trimmed binary search tree.

```
Example 1:
Input:
    1
   / \
  0   2

  L = 1
  R = 2

Output:
    1
      \
       2
Example 2:
Input:
    3
   / \
  0   4
   \
    2
   /
  1

  L = 1
  R = 3

Output:
      3
     /
   2
  /
 1
```

## java Solution:

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
    public TreeNode trimBST(TreeNode root, int L, int R) {
        if(root == null){
           return root;
        }

        if(root.val > R){
            return trimBST(root.left,L,R);
        }
        else if(root.val < L){
            return trimBST(root.right,L,R);
        }
        else{
            root.left = trimBST(root.left,L,R);
            root.right = trimBST(root.right,L,R);
        }
        return root;
    }
}
```

Kotlin Solution:

```kotlin
fun trimBST(root: TreeNode?, L: Int, R: Int): TreeNode? {
        if (root == null) {
            return root
        }

        if (root.`val` > R) {
            return trimBST(root.left, L, R)
        } else if (root.`val` < L) {
            return trimBST(root.right, L, R)
        } else {
            root.left = trimBST(root.left, L, R)
            root.right = trimBST(root.right, L, R)
        }
        return root
    }
```


