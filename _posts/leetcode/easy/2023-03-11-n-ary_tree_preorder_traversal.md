---
layout:     post
title:      "N-ary Tree Preorder Traversal"
summary:    "\"N 叉树的前序遍历\""
date:       2023-03-11 14:30:48
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

# N-ary Tree Preorder Traversal


Given an n-ary tree, return the preorder traversal of its nodes' values.

For example, given a 3-ary tree:


Return its preorder traversal as: [1,3,5,6,2,4].

## java Solution:
```java

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

public class Solution {
    List<Integer> myList;
    Solution(){
       myList = new LinkedList<>();
    }

    public List<Integer> preorder(Node root) {
        reversePreorder(root);
        return myList;
    }

    private void reversePreorder(Node root){
        if(root == null) return;
        if(root.children == null){
            myList.add(root.val);
        }
        else{
            myList.add(root.val);
            for(Node ele: root.children){
                reversePreorder(ele);
            }
        }
    }
}
```

//Iterative

```
class Solution {
    public List<Integer> preorder(Node root) {
        Deque<Node> myDequeue = new LinkedList<>();
        List<Integer> myList = new LinkedList<>();
        if(root == null) return myList;
        myDequeue.addFirst(root);
        while(!myDequeue.isEmpty()){
            Node tmp = myDequeue.pollFirst();
            myList.add(tmp.val);
            if(tmp.children != null){
                Collections.reverse(tmp.children);
                for(Node ele: tmp.children){
                    myDequeue.addFirst(ele);
                }
            }
        }
        return myList;
    }
}
```

