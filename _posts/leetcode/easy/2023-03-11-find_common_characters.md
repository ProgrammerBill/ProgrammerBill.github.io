---
layout:     post
title:      "Find Common Characters"
summary:    "\"查找共用字符\""
date:       2023-03-11 16:07:57
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

# Find Common Characters

Given a string array words, return an array of all characters that show up in all strings within the words (including duplicates). You may return the answer in any order.

```
Example 1:

Input: words = ["bella","label","roller"]
Output: ["e","l","l"]
Example 2:

Input: words = ["cool","lock","cook"]
Output: ["c","o"]
```

##  Java Solution

```Java
class Solution {
    public List<String> commonChars(String[] A) {
        int len = A.length;
        List<Integer[]> myList = new LinkedList<>();
        for(int i = 0;i < len; i++){
            Integer[] myVal = new Integer[26];
            for(int k = 0;k < 26;k++){
               myVal[k] = 0;
            }
            String tmp = A[i];
            for(int j = 0; j < tmp.length();j++){
                myVal[tmp.charAt(j) - 'a']++;
            }
            //for(int k = 0;k < 26;k++){
            //    System.out.print(myVal[k] + " ");
            //}
            //System.out.println(" ");
            myList.add(myVal);
        }
        List<String> myString = new LinkedList<>();
        for(int i = 0; i < 26 ;i++){
            int min = Integer.MAX_VALUE;
            for(Integer[] ele:myList){
                int num = ele[i];
                if(num == 0){
                    min = 0;
                    break;
                }
                if(num < min){
                    min = num;
                }
            }
            for(int j = 0;j < min;j++){
                myString.add(String.valueOf(Character.toChars('a' + i)));
            }

        }
        return myString;
    }
}
```
