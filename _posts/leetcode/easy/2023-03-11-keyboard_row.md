---
layout:     post
title:      "Keyboard Row"
summary:    "\"键盘行\""
date:       2023-03-11 14:17:53
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

# Keyboard Row

Given a List of words, return the words that can be typed using letters of alphabet on only one row's of American keyboard like the image below.

```
Example:

Input: ["Hello", "Alaska", "Dad", "Peace"]
Output: ["Alaska", "Dad"]
```

## Java Solution:

```java
    private Set<Character> firstSet = new HashSet<>();
    private Set<Character> secondSet = new HashSet<>();
    private Set<Character> thirdSet = new HashSet<>();

    String firstRow = "qwertyuiop";
    String secondRow = "asdfghjkl";
    String thirdRow = "zxcvbnm";

    public void initSets(){
        for (char mChar:firstRow.toCharArray()) {
            firstSet.add(mChar);
            firstSet.add(Character.toUpperCase(mChar));
        }

        for (char mChar:secondRow.toCharArray()) {
            secondSet.add(mChar);
            secondSet.add(Character.toUpperCase(mChar));
        }

        for (char mChar:thirdRow.toCharArray()) {
            thirdSet.add(mChar);
            thirdSet.add(Character.toUpperCase(mChar));
        }
    }

    Solution(){
        initSets();
    }

    public String[] findWords(String[] words) {
        List<String> ret = new LinkedList<>();
        for(String str: words){
            int []whichRows = {0,0,0};
            for(char mChar:str.toCharArray()){
                if(isFromFirstSets(mChar)){
                    whichRows[0] = 1;
                }
                else if(isFromSecondSets(mChar)){
                    whichRows[1] = 1;
                }
                else if (isFromThirdSets(mChar)){
                    whichRows[2] = 1;
                }
            }
            int sum = 0;
            for(int ele:whichRows){
               sum += ele;
            }
            if(sum == 1){
                ret.add(str);
            }
        }
        String []retStr = new String[ret.size()];
        ret.toArray(retStr);
        return retStr;
    }

    private Boolean isFromFirstSets(char mChar){
        return firstSet.contains(mChar);
    }

    private Boolean isFromSecondSets(char mChar){
        return secondSet.contains(mChar);
    }

    private Boolean isFromThirdSets(char mChar){
        return thirdSet.contains(mChar);
    }
}
```

