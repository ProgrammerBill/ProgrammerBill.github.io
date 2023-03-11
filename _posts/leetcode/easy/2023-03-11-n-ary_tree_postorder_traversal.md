---
layout:     post
title:      "N-ary Tree Postorder Traversal"
summary:    "\"N 叉树的后序遍历\""
date:       2023-03-11 14:32:52
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

# N-ary Tree Postorder Traversal


Given an n-ary tree, return the postorder traversal of its nodes' values.

For example, given a 3-ary tree:


Return its postorder traversal as: [5,6,3,2,4,1].


Note:

Recursive solution is trivial, could you do it iteratively?

## Java Solution:

```Java
/*
// Definition for a Node.
class Node {
    public int val;
    public List<Node> children;

    public Node() {}

    public Node(int _val,List<Node> _children) {
        val = _val;
        children = _children;
    }
};
*/
class Solution {
 public List<Integer> postorder(Node root) {
        List<Integer> myList = new LinkedList<>();
        Stack<Node> myStack = new Stack<>();
        if(root == null) return myList;
        myStack.add(root);
        while(!myStack.isEmpty()){
            Node tmp = myStack.pop();
            myList.add(tmp.val);
            if(tmp.children == null) continue;
            for(Node node: tmp.children){
                myStack.add(node);
            }
        }
        Collections.reverse(myList);
        return myList;
    }
}
```

//recursive
Solution:

```java
class Solution {
  public List<Integer> myList;
    public List<Integer> postorder(Node root) {
        myList = new LinkedList<>();
        postReverse(root);
        return myList;
    }
    private void postReverse(Node root){
        if(root == null) return;
        if(root.children == null){
            myList.add(root.val);
        }
        else{
            for(Node node:root.children){
                postReverse(node);
            }
            myList.add(root.val);
        }
    }
}
```

