---
layout:     post
title:      "Insert Interval"
summary:    "\"default\""
date:       2023-11-21 09:11:23
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

# Insert Interval

You are given an array of non-overlapping intervals intervals where intervals[i] = [starti, endi] represent the start and the end of the ith interval and intervals is sorted in ascending order by starti. You are also given an interval newInterval = [start, end] that represents the start and end of another interval.

Insert newInterval into intervals such that intervals is still sorted in ascending order by starti and intervals still does not have any overlapping intervals (merge overlapping intervals if necessary).

Return intervals after the insertion.


```
Example 1:

Input: intervals = [[1,3],[6,9]], newInterval = [2,5]
Output: [[1,5],[6,9]]
Example 2:

Input: intervals = [[1,2],[3,5],[6,7],[8,10],[12,16]], newInterval = [4,8]
Output: [[1,2],[3,10],[12,16]]
Explanation: Because the new interval [4,8] overlaps with [3,5],[6,7],[8,10].


Constraints:

0 <= intervals.length <= 104
intervals[i].length == 2
0 <= starti <= endi <= 105
intervals is sorted by starti in ascending order.
newInterval.length == 2
0 <= start <= end <= 105
```

# Solution

```c++

class Solution {
  public:
  vector<vector<int>> insert(vector<vector<int>>& intervals,
                             vector<int>& newInterval) {
    vector<vector<int>> ans;
    intervals.push_back(newInterval);
    ans = merge(intervals);
    return ans;
  }

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

