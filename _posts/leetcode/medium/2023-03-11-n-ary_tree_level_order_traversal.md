---
layout:     post
title:      "N-ary Tree Level Order Traversal"
summary:    "\"N 叉树的层序遍历\""
date:       2023-03-11 13:46:16
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

# N-ary Tree Level Order Traversal


Given an n-ary tree, return the level order traversal of its nodes' values. (ie, from left to right, level by level).

For example, given a 3-ary tree:

![](/img/bill/in-posts//)

We should return its level order traversal:

[
     [1],
     [3,2,4],
     [5,6]
]


## Java Solution:

```java
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
    public List<List<Integer>> levelOrder(Node root) {
        List<List<Integer>> myList = new LinkedList<>();
        Queue<Node> myQueue = new LinkedList<>();
        if(root == null) return myList;
        myQueue.add(root);
        int currentSize = 1;
        int nextSize = 0;
        List<Integer> tmpList = new LinkedList<>();
        while(!myQueue.isEmpty()){
            Node tmp = myQueue.poll();
            tmpList.add(tmp.val);

            if(tmp.children != null){
                for(int i = 0; i < tmp.children.size();i++){
                    myQueue.add(tmp.children.get(i));
                }
                nextSize += tmp.children.size();
            }
            currentSize = currentSize - 1;
            if(currentSize == 0){
                myList.add(tmpList);
                tmpList = new LinkedList<>();
                currentSize = nextSize;
                nextSize = 0;
            }

        }
        return myList;
    }
}
```

