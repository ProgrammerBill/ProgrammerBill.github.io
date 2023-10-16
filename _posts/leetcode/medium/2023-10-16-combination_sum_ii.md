---
layout:     post
title:      "Combination Sum II"
summary:    "\"default\""
date:       2023-10-16 18:17:28
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


# Combination Sum II



Given a collection of candidate numbers (candidates) and a target number (target), find all unique combinations in candidates where the candidate numbers sum to target.

Each number in candidates may only be used once in the combination.

Note: The solution set must not contain duplicate combinations.


```
Example 1:

Input: candidates = [10,1,2,7,6,1,5], target = 8
Output:
[
[1,1,6],
[1,2,5],
[1,7],
[2,6]
]
Example 2:

Input: candidates = [2,5,2,1,2], target = 5
Output:
[
[1,2,2],
[5]
]
```

# solution

```c++
class Solution {
  private:
  vector<vector<int>> ret;

  public:
  void dfs(vector<int>& candidates, int target, vector<int> current,
           int begin) {
    if (target < 0) {
      return;
    } else if (target == 0) {
      ret.push_back(current);
      return;
    }
    for (int i = begin; i < candidates.size(); i++) {
      if (i > begin && candidates[i] == candidates[i - 1]) {
        continue;
      }
      current.push_back(candidates[i]);
      dfs(candidates, target - candidates[i], current, i + 1);
      current.pop_back();
    }
  }

  vector<vector<int>> combinationSum2(vector<int>& candidates, int target) {
    int sum_of_elems = 0;
    for (auto& n : candidates)
           sum_of_elems += n;
    if (sum_of_elems < target) {
      return vector<vector<int>>();
    }
    vector<int> current;
    sort(candidates.begin(), candidates.end());
    dfs(candidates, target, current, 0);
    return ret;
  }
};

```



