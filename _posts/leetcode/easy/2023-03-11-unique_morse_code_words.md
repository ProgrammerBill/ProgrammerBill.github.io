---
layout:     post
title:      "Unique Morse Code Words"
summary:    "\"唯一摩尔斯密码词\""
date:       2023-03-11 14:54:06
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


# Unique Morse Code Words

Description

International Morse Code defines a standard encoding where each letter is mapped to a series of dots and dashes, as follows: "a" maps to ".-", "b" maps to "-...", "c" maps to "-.-.", and so on.

For convenience, the full table for the 26 letters of the English alphabet is given below:

```
[".-","-...","-.-.","-..",".","..-.","--.","....","..",".---","-.-",".-..","--","-.","---",".--.","--.-",".-.","...","-","..-","...-",".--","-..-","-.--","--.."]
```


Now, given a list of words, each word can be written as a concatenation of the Morse code of each letter. For example, "cba" can be written as "-.-.-....-", (which is the concatenation "-.-." + "-..." + ".-"). We'll call such a concatenation, the transformation of a word.

Return the number of different transformations among all words we have.

```
Example:
Input: words = ["gin", "zen", "gig", "msg"]
Output: 2
Explanation:
The transformation of each word is:
"gin" -> "--...-."
"zen" -> "--...-."
"gig" -> "--...--."
"msg" -> "--...--."
```

There are 2 different transformations, "--...-." and "--...--.".

Note:

- The length of words will be at most 100.
- Each words[i] will have length in range [1, 12].
- words[i] will only consist of lowercase letters.

## Java Solution:

```java
import java.util.HashSet;
import java.util.Set;

/**
 * Created by bill on 11/13/18.
 */
public class Solution {
    public final String []morseDict = {
	    ".-","-...","-.-.","-..",".","..-.","--.","....","..",
	    ".---","-.-",".-..","--","-.","---",".--.","--.-",".-.",
	    "...","-","..-","...-",".--","-..-","-.--","--.."};
    public int uniqueMorseRepresentations(String[] words) {
        Set<String> myHashSet = new HashSet<String>();
        for(String word: words){
            StringBuilder myStringBuilder = new StringBuilder();
            for(char ele: word.toCharArray()){
                myStringBuilder.append(morseDict[ele - 'a']);
            }
            String myStr = myStringBuilder.toString();
            if(!myHashSet.contains(myStr)){
                 myHashSet.add(myStr);
            }
        }
        return myHashSet.size();
    }
}
```

