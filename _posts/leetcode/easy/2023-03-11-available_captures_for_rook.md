---
layout:     post
title:      "Available Captures for Rook"
summary:    "\"可以被一步捕获的棋子数\""
date:       2023-03-11 15:58:40
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

# Available Captures for Rook

On an 8 x 8 chessboard, there is one white rook.  There also may be empty squares, white bishops, and black pawns.  These are given as characters 'R', '.', 'B', and 'p' respectively. Uppercase characters represent white pieces, and lowercase characters represent black pieces.

The rook moves as in the rules of Chess: it chooses one of four cardinal directions (north, east, west, and south), then moves in that direction until it chooses to stop, reaches the edge of the board, or captures an opposite colored pawn by moving to the same square it occupies.  Also, rooks cannot move into the same square as other friendly bishops.

Return the number of pawns the rook can capture in one move.

Example 1:



```
Input: [[".",".",".",".",".",".",".","."],[".",".",".","p",".",".",".","."],[".",".",".","R",".",".",".","p"],[".",".",".",".",".",".",".","."],[".",".",".",".",".",".",".","."],[".",".",".","p",".",".",".","."],[".",".",".",".",".",".",".","."],[".",".",".",".",".",".",".","."]]
Output: 3
Explanation:
In this example the rook is able to capture all the pawns.
```

Example 2:


```
Input: [[".",".",".",".",".",".",".","."],[".","p","p","p","p","p",".","."],[".","p","p","B","p","p",".","."],[".","p","B","R","B","p",".","."],[".","p","p","B","p","p",".","."],[".","p","p","p","p","p",".","."],[".",".",".",".",".",".",".","."],[".",".",".",".",".",".",".","."]]
Output: 0
Explanation:
Bishops are blocking the rook to capture any pawn.
```

Example 3:


```
Input: [[".",".",".",".",".",".",".","."],[".",".",".","p",".",".",".","."],[".",".",".","p",".",".",".","."],["p","p",".","R",".","p","B","."],[".",".",".",".",".",".",".","."],[".",".",".","B",".",".",".","."],[".",".",".","p",".",".",".","."],[".",".",".",".",".",".",".","."]]
Output: 3
Explanation:
The rook can capture the pawns at positions b5, d6 and f5.
```

## Java Solution:

```java

public class Solution {

    Boolean north = false;
    Boolean south = false;
    Boolean east = false;
    Boolean west = false;
    class Rooks extends Point{
        Rooks(int x, int y){
            super(x,y);
        }
    }

    class Point{
        Point(int x,int y){
            this.x = x;
            this.y = y;
        }
        int x;
        int y;
    }

    List<Point> blackPawns = new LinkedList<>();
    List<Point> whiteBishops = new LinkedList<>();
    Rooks mRooks;
    public int numRookCaptures(char[][] board) {
        int height = board.length;
        int width = board[0].length;
        int sum = 0;
        for(int i = 0; i < height ;i++){
            for(int j = 0; j < width ;j++) {
                char tmp = board[i][j];
                switch (tmp){
                    case 'R':
                        mRooks = new Rooks(i,j);
                        break;
                    case 'B':
                        blackPawns.add(new Point(i,j));
                        break;
                    case 'p':
                        whiteBishops.add(new Point(i,j));
                        break;
                    default: break;
                }
            }
        }
        for(int i = 0; i < whiteBishops.size();i++){
            if(whiteBishops.get(i).x == mRooks.x){
                int whiteBishopsY = whiteBishops.get(i).y;
                int max = whiteBishopsY > mRooks.y ? whiteBishopsY  : mRooks.y;
                int min = whiteBishopsY < mRooks.y ? whiteBishopsY  : mRooks.y;
                if(blackPawns.size() == 0){
                    if(whiteBishopsY > mRooks.y) {
                        if(!north){
                            north = true;
                            sum++;
                        }
                    }
                    if(whiteBishopsY < mRooks.y) {
                        if(!south){
                            south = true;
                            sum++;
                        }
                    }
                    continue;
                }
                Boolean hasBlackPawns = false;
                for(int j = 0; j < blackPawns.size();j++){
                    int blackPawnsY = blackPawns.get(j).y;
                    if(blackPawns.get(j).x == mRooks.x){
                        if(blackPawnsY < max && blackPawnsY > min){
                            if(!north||!south){
                                hasBlackPawns = true;
                                break;
                            }
                        }
                    }
                }

                if(!hasBlackPawns){
                    if(whiteBishopsY > mRooks.y) {
                        if(!north){
                            north = true;
                            sum++;
                        }
                    }
                    if(whiteBishopsY < mRooks.y) {
                        if(!south){
                            south = true;
                            sum++;
                        }
                    }
                }
            }
        }
        for(int i = 0; i < whiteBishops.size();i++){
            if(whiteBishops.get(i).y == mRooks.y){
                int whiteBishopsX = whiteBishops.get(i).x;
                int max = whiteBishopsX > mRooks.x ? whiteBishopsX : mRooks.x;
                int min = whiteBishopsX < mRooks.x ? whiteBishopsX : mRooks.x;
                if(blackPawns.size() == 0){
                    if(whiteBishopsX > mRooks.x) {
                        if(!east){
                            east = true;
                            sum++;
                        }
                    }
                    if(whiteBishopsX < mRooks.x) {
                        if(!west){
                            west = true;
                            sum++;
                        }
                    }
                    continue;
                }
                Boolean hasBlackPawns = false;
                for(int j = 0; j < blackPawns.size();j++){
                    int blackPawnsX = blackPawns.get(j).x;
                    if(blackPawns.get(j).y == mRooks.y){
                        if(blackPawnsX < max && blackPawnsX > min){
                            if(!east||!west) {
                                hasBlackPawns = true;
                                break;
                            }
                        }
                    }
                }
                if(!hasBlackPawns){
                    if(whiteBishopsX > mRooks.x) {
                        if(!east){
                            east = true;
                            sum++;
                        }
                    }
                    if(whiteBishopsX < mRooks.x) {
                        if(!west){
                            west = true;
                            sum++;
                        }
                    }
                }
            }
        }
        return sum;
    }
}
```


