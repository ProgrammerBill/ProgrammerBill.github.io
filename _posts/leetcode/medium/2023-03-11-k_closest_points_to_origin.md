---
layout:     post
title:      "K Closest Points to Origin"
summary:    "\"最接近原点的 K 个点\""
date:       2023-03-11 15:50:09
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

# K Closest Points to Origin


We have a list of points on the plane.  Find the K closest points to the origin (0, 0).

(Here, the distance between two points on a plane is the Euclidean distance.)

You may return the answer in any order.  The answer is guaranteed to be unique (except for the order that it is in.)


```
Example 1:

Input: points = [[1,3],[-2,2]], K = 1
Output: [[-2,2]]
Explanation:
The distance between (1, 3) and the origin is sqrt(10).
The distance between (-2, 2) and the origin is sqrt(8).
Since sqrt(8) < sqrt(10), (-2, 2) is closer to the origin.
We only want the closest K = 1 points from the origin, so the answer is just [[-2,2]].
Example 2:

Input: points = [[3,3],[5,-1],[-2,4]], K = 2
Output: [[3,3],[-2,4]]
(The answer [[-2,4],[3,3]] would also be accepted.)
```

## Java Solution:

```java
class Solution {
    class point{
        point(int x,int y){
            this.x = x;
            this.y = y;
        }
        int x;
        int y;
    }

    class pointId{
        pointId(point mid, int mDis){
            id = mid;
            distance = mDis;
        }
        point id;
        int distance;
    }

    private Comparator<pointId> mComparator = new Comparator<pointId>(){
        @Override
        public int compare(pointId t1, pointId t2) {
            return t1.distance - t2.distance;
        }
    };

    public int[][] kClosest(int[][] points, int K) {
        int len = points.length;
        Queue<pointId> mQueue = new PriorityQueue<>(K, mComparator);
        for (int []ele:points) {
            int distance = EuclideanDistance(ele[0],ele[1],0,0);
            pointId mId = new pointId(new point(ele[0],ele[1]), distance);
            mQueue.add(mId);
        }

        int [][] closest = new int[K][2];
        int i = 0;
        while(i < K){
            pointId tmp = mQueue.poll();
            closest[i][0] = tmp.id.x;
            closest[i][1] = tmp.id.y;
            i++;
        }
        return closest;
    }

    private static int EuclideanDistance(int X, int Y, int oX, int oY){
        int tmp = (X - oX) * (X - oX) + (Y - oY) * (Y - oY);
        return tmp;
    }
}
```

