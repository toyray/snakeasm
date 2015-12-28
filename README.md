## snakeasm

Snake clone written in Intel x86 ASM back in 2003.

Requires [MASM32 SDK](http://www.masm32.com/) for assembly and linking.

### Contents
- [Introduction](#introduction)
- [Implementation](#implementation)
- [To Do](#to-do)
- [Credits](#credits)


### Introduction

A simple Nokia Snake clone written to demonstrate use of a queue data structure. Fully playable but the score has not been implemented yet. It is intended to be a demonstration example on the use of a queue data structure. A quick explanation on the implementation can be 
below.

### Implementation

A queue is used to store items that is to be processed in a FIFO (First In First Out) manner. Items can be bytes, words, dwords or even structures.

Operations on a queue include adding items which will insert items at the back of the queue, removing items, which will remove items at the front of the queue. Memory is allocated dynamically for the new items and de-allocated when items are deleted so the maximium number of items is determined by the amount of available memory.

For this implementation, the snake movement is animated by painting the new snake head's location black (the colour of the snake) and painting the tail location white (the colour of the background). In this way, there is no need to repaint the entire game screen, as only two pixels need to be painted.

To keep track of the changes in direction caused by the player pressing the cursor keys, changes in direction as well the location where the change occurs is saved onto the queue. Everytime the snake tail is painted, it checks the first item in the queue and determines whether it needs to paint in a different direction. If yes, it will discard the first item from the queue and continue painting until the next change in direction is encountered. 

When the queue is no longer being used such as exiting the application, all memory associated with the queue and its data is freed.

The main implementation of the queue operations is in [queue.asm](src/queue.asm). For more details on the actual game implementation, please look in [snake.asm](src/snake.asm)

### To Do

- Score is not implemented yet
- There is no proper interface to start or stop a game currently. Left-clicking in the window after dying will start a new game

### Credits

Credit goes to the following people for the MASM32 development package and Win32 ASM tutorials respectively.

- Steve Hutchesson - [www.movsd.com](http://www.movsd.com)
- Iczelion		 - [win32asm.cjb.net](http://win32asm.cjb.net)