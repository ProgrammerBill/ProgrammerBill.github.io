---
layout:     post
title:      "Maximum Binary Tree"
summary:    "\"最大二叉树\""
date:       2023-03-11 14:36:56
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

# Maximum Binary Tree

Description

Given an integer array with no duplicates. A maximum tree building on this array is defined as follow:

    The root is the maximum number in the array.
    The left subtree is the maximum tree constructed from left part subarray divided by the maximum number.
    The right subtree is the maximum tree constructed from right part subarray divided by the maximum number.

Construct the maximum tree by the given array and output the root node of this tree.

```
Example 1:

Input: [3,2,1,6,0,5]
Output: return the tree root node representing the following tree:

      6
    /   \
   3     5
    \    /
     2  0
       \
        1

```

Note:

- The size of the given array will be in the range [1,1000].


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
    public TreeNode constructMaximumBinaryTree(int[] nums) {
         if(nums.length == 0){
            return null;
        }
        int maxIndex = 0;
        int maxVal = nums[0];
        for(int index = 0;index < nums.length; index++){
            if(nums[index] > maxVal){
                maxVal = nums[index];
                maxIndex = index;
            }
        }
        TreeNode root = new TreeNode(maxVal);
        if(maxIndex - 1 >= 0){
            root.left = constructMaximumBinaryTree(Arrays.copyOfRange(nums,0,maxIndex));
        }
        if(maxIndex + 1 <= nums.length - 1){
            root.right = constructMaximumBinaryTree(Arrays.copyOfRange(nums,maxIndex + 1,nums.length));
        }
        return root;
    }
}
```

A better Solution:

```java
class Solution {
    public TreeNode constructMaximumBinaryTree(int[] nums) {
        Deque<TreeNode> stack = new LinkedList<>();
        for(int i = 0; i < nums.length; i++) {
            TreeNode curr = new TreeNode(nums[i]);
            while(!stack.isEmpty() && stack.peek().val < nums[i]) {
                curr.left = stack.pop();
            }
            if(!stack.isEmpty()) {
                stack.peek().right = curr;
            }
            stack.push(curr);
        }

        return stack.isEmpty() ? null : stack.removeLast();
    }
}
```


