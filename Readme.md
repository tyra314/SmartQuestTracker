About
=====

This is an addon for World of Warcraft in form of an ElvUI plugin.
It will try to keep relevant quest in the quest tracker and remove the unrelevant ones.

How it works
============

If you are any like me, then you'll have a ton of quest in your Quest Log lurking around.
Also, your quest tracked is filled with quests, which you're not even remotely working on right now.
This plugin tries to solve this issue by only track those quests, which are near to your current location.
Every other quest will be automatically untracked. 

When you enter the world with your character (or reload your UI) all quest will be untracked.
So you start with a clean quest tracker. The addon then adds all quests, which are located at
our current zone, to the quest tracker. Whenever you switch areas (the white text appears, 
telling you, where you are now), the list of tracked quests is updated. All quests, which had
been added automatically and are not in your current zone, are untracked.

When you accept a new quest, it gets added to the quest tracker, so you can be sure, you have 
the quest accepted. Additionally, it is marked as automatically added, such that, when you
change the area, it is treated properly.

Expected issues
===================

It's not trivial to decide, which quests are near to you for several reasons.

First, there are quests, which can be done anywhere in the whole world.
(e.g. http://www.wowhead.com/quest=29507/fun-for-the-little-ones)
Obviously, there aren't any useful information about the location of such quests.
Therefor, such quests can't be tracked automatically by any means.
If you like to work on such quests, you have to track them manually.

With that out of the way, we can come to a more sad topic. There are several different
hints, the WoW Addon interface provides regarding quest locations. I tried to priorize
them in the best order, but it may not be perfect.

Also the information provided isn't always helpful. For instance, dungeon quests give
the hint, that they are in the zone, there the dungeon is located. However, I prefer
to only show them in the dungeon itself.

Last but not least, zone borders are a hard thing. A quest might be just few steps ahead,
but if they are in a different zone, when they will not show up in the tracker.

If you encounter any quests, which are tracked, but should not and vice versa, please let me know.

License
=======

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.
