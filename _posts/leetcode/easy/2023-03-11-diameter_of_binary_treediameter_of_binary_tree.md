---
layout:     post
title:      "Diameter of Binary TreeDiameter of Binary Tree"
summary:    "\"二叉树的直径\""
date:       2023-03-11 14:28:16
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

# Diameter of Binary Tree


iven a binary tree, you need to compute the length of the diameter of the tree. The diameter of a binary tree is the length of the longest path between any two nodes in a tree. This path may or may not pass through the root.

```
Example:
Given a binary tree
          1
         / \
        2   3
       / \
      4   5
Return 3, which is the length of the path [4,2,1,3] or [5,2,1,3].
```

Note: The length of path between two nodes is represented by the number of edges between them.

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
    public int diameterOfBinaryTree(TreeNode root) {
        if(root == null){
            return 0;
        }
        int maxLeft = diameterOfBinaryTree(root.left);
        int maxRight = diameterOfBinaryTree(root.right);
        int max = maxLeft > maxRight ? maxLeft : maxRight;

        int diameter = getDepth(root.left) + getDepth(root.right);
        if(max < diameter){
            return diameter;
        }
        else{
            return max;
        }
    }

    private int getDepth(TreeNode root){
        if(root != null){
            return Math.max(getDepth(root.left), getDepth(root.right)) + 1;
        }
        return 0;
    }
}
```

--------------------------------------------

Approach #1: Depth-First Search [Accepted]
Intuition

Any path can be written as two arrows (in different directions) from some node, where an arrow is a path that starts at some node and only travels down to child nodes.

If we knew the maximum length arrows L, R for each child, then the best path touches L + R + 1 nodes.

Algorithm

Let's calculate the depth of a node in the usual way: max(depth of node.left, depth of node.right) + 1. While we do, a path "through" this node uses 1 + (depth of node.left) + (depth of node.right) nodes. Let's search each node and remember the highest number of nodes used in some path. The desired length is 1 minus this number.

```java
class Solution {
    int ans;
    public int diameterOfBinaryTree(TreeNode root) {
        ans = 1;
        depth(root);
        return ans - 1;
    }
    public int depth(TreeNode node) {
        if (node == null) return 0;
        int L = depth(node.left);
        int R = depth(node.right);
        ans = Math.max(ans, L+R+1);
        return Math.max(L, R) + 1;
    }
}
```

Complexity Analysis

- Time Complexity: O(N)O(N). We visit every node once.

- Space Complexity: O(N)O(N), the size of our implicit call stack during our depth-first search.


