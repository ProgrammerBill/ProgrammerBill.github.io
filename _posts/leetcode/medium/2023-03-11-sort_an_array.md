---
layout:     post
title:      "Sort an Array"
summary:    "\"排序数组\""
date:       2023-03-11 15:36:29
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


# Sort an Array

Given an array of integers nums, sort the array in ascending order.


```
Example 1:

Input: nums = [5,2,3,1]
Output: [1,2,3,5]
Example 2:

Input: nums = [5,1,1,2,0,0]
Output: [0,0,1,1,2,5]


Constraints:

1 <= nums.length <= 50000
-50000 <= nums[i] <= 50000
```

## C++ Solution

```c++
class Solution {

    public:
        vector<int> sortArray(vector<int>& nums) {
            quick_sort(nums, 0, nums.size() - 1);
            return nums;
        }

        void quick_sort(vector<int>& nums, int l, int r)
        {

            if (l < r)
            {

                int i = l, j = r, x = nums[l];
                while (i < j)
                {

                    while(i < j && nums[j] >= x)
                        j--;
                    if(i < j)
                        nums[i++] = nums[j];

                    while(i < j && nums[i] < x)
                        i++;
                    if(i < j)
                        nums[j--] = nums[i];
                }
                nums[i] = x;
                quick_sort(nums, l, i - 1);
                quick_sort(nums, i + 1, r);
            }
        }
};
```

