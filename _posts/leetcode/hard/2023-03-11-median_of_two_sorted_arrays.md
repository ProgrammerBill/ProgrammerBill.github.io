---
layout:     post
title:      "Median of Two Sorted Arrays"
summary:    "\"寻找两个正序数组的中位数\""
date:       2023-03-11 12:38:18
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

# Median of Two Sorted Arrays

Given two sorted arrays nums1 and nums2 of size m and n respectively, return the median of the two sorted arrays.

The overall run time complexity should be O(log (m+n)).


```
Example 1:

Input: nums1 = [1,3], nums2 = [2]
Output: 2.00000
Explanation: merged array = [1,2,3] and median is 2.
Example 2:

Input: nums1 = [1,2], nums2 = [3,4]
Output: 2.50000
Explanation: merged array = [1,2,3,4] and median is (2 + 3) / 2 = 2.5.
Example 3:

Input: nums1 = [0,0], nums2 = [0,0]
Output: 0.00000
Example 4:

Input: nums1 = [], nums2 = [1]
Output: 1.00000
Example 5:

Input: nums1 = [2], nums2 = []
Output: 2.00000


Constraints:

nums1.length == m
nums2.length == n
0 <= m <= 1000
0 <= n <= 1000
1 <= m + n <= 2000
-106 <= nums1[i], nums2[i] <= 106
```

## C++ Solution

```
#include<iostream>
#include<vector>
#include<set>
using namespace std;
class Solution {
  public:
    Solution() {}
    double findMedianSortedArrays(vector<int>& nums1, vector<int>& nums2) {
      int i = 0, j = 0;
      int len = nums1.size() + nums2.size();
      int target_size = 0;
      if (len % 2 == 1) {
        target_size = (len - 1)/ 2 + 1;
      } else {
        target_size = len / 2 + 1;
      }
      vector<int> ret;
      vector<int>::iterator iter1 = nums1.begin();
      vector<int>::iterator iter2 = nums2.begin();
      while (ret.size() < target_size) {
          if (iter1 == nums1.end()) {
            ret.push_back(*iter2);
            iter2++;
          } else if (iter2 == nums2.end()) {
            ret.push_back(*iter1);
            iter1++;
          } else if (*iter1 < *iter2) {
            ret.push_back(*iter1);
            iter1++;
          } else {
            ret.push_back(*iter2);
            iter2++;
          }
      }
      if (len % 2 == 1) {
        return ret.back();
      } else {
        return (ret.back() + ret[ret.size() - 2]) / 2.0;
      }
    }
};

void test(vector<int> nums1, vector<int> nums2, double expect) {
  Solution *a = new Solution();
  double ret = a->findMedianSortedArrays(nums1, nums2);
  cout<<"ret = "<<ret<<endl;
  if (ret == expect) {
    cout<<"tets passed!"<<endl;
  } else {
    cout<<"tets failed!"<<endl;
  }
  delete a;
}

int main() {
  test(vector<int>{1,3}, vector<int>{2}, 2.00);
  test(vector<int>{1,2}, vector<int>{3,4}, 2.5);
  test(vector<int>{0}, vector<int>{0}, 0);
  test(vector<int>{}, vector<int>{1}, 1);
  test(vector<int>{2}, vector<int>{}, 2);
}
```

