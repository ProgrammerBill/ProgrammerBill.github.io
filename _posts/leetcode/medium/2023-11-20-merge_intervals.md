---
layout:     post
title:      "Merge Intervals"
summary:    "\"default\""
date:       2023-11-20 17:21:55
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

# Merge Intervals

```
Given an array of intervals where intervals[i] = [starti, endi], merge all overlapping intervals, and return an array of the non-overlapping intervals that cover all the intervals in the input.



Example 1:

Input: intervals = [[1,3],[2,6],[8,10],[15,18]]
Output: [[1,6],[8,10],[15,18]]
Explanation: Since intervals [1,3] and [2,6] overlap, merge them into [1,6].
Example 2:

Input: intervals = [[1,4],[4,5]]
Output: [[1,5]]
Explanation: Intervals [1,4] and [4,5] are considered overlapping.


Constraints:

1 <= intervals.length <= 104
intervals[i].length == 2
```

# Solution

```c++
class Solution {
  public:
  vector<vector<int>> merge(vector<vector<int>>& intervals) {
    vector<vector<int>> ans;
    sort(intervals.begin(), intervals.end());
    int pairSize = intervals.size();
    for (int i = 0; i < pairSize;) {
      int start = intervals[i][0];
      int end = intervals[i][1];
      vector<int> tmp;
      int j = 0;
      for (j = i + 1; j < pairSize; j++) {
        int nextStart = intervals[j][0];
        int nextEnd = intervals[j][1];
        if (nextStart > end) {
          break;
        } else {
          if (nextEnd > end) {
            end = nextEnd;
          }
        }
      }
      tmp.push_back(start);
      tmp.push_back(end);
      ans.push_back(tmp);
      i = j;
    }
    return ans;
  }
};
```
