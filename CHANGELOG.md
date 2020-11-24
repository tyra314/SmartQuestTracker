v4.0.3:

- Fixes a bug in handling of accepted, updated and removed quests

v4.0.2:

- Fixes a dumb bug preventing the untracking of quests
- Update to 9.0.2

v4.0.1:

- Fixes unexpected nil value errors
- Minor refactoring

v4.0.0:

- Update for Shadowlands PTR

v3.1.8:

-   Fixes a lua error when quests is nil during map transitions

v3.1.7:

-   Adds a rescan interval option for zen mode
-   Fixes lua error when mapID is nil during map transitions
-   Fixes quest log not usable when zen mode is active
-   Adds zen mode, which allows to focus on quests
-   Fixes some issues in the tracking of quest
-   Adds new option "Untrack Quest Waypoints". With this option all quests which read like "Use portal to get ..." can be removed from the quest tracker.
-   Adds new option "Keep story quests". With this options you can untrack quests with the alliance or horde icon next to them. They are pretty obnoxious.
-   Adds new option "Handling of completed quests". With this option, you can either untrack all completed quests, track all completed quests, or keep only the local ones.

Note: The "Untrack Quest Waypoints" doesn't work for all quests. If the only visible objective of an qwuest is the use of the portal, then it will be kept tracked.

v3.1.2:

-   Update to Rise of Azshara

v3.1.1:

-   Update to Tides of Vengeance

v3.1.0:

- Update to BfA prepatch
- Ported changes of 2.1.0

v3.0.0:

-   Update to BfA beta

v2.1.0:

-   Performance improvemtents
-   Distributing update of quests over several frames to decrease lag

v2.0.13:

-   Fixes untracking of completed quests

v2.0.12:

-   Improved World quest handling
-   (Internal) More shared code between ElvUI version
-   (Internal) Adds debug messages

v2.0.11:

-   Interface version bump to 7.3
-   (Internal) Change build process of addon.

v2.0.10:

-   Fixes settings don't get saved between sessions

v2.0.9:

-   Interface version bump to 7.2
-   Merge improvements of ElvUI version

v2.0.4:

-   Interface version bump to 7.1

v2.0.3:

-   Fixes broken download archive

v2.0.2:

-   Sorting of quests should now be done more frequently
-   Fixes a bug, which prevented the untracking of quests in certain circumstances

v2.0.1:

-   Fixes reported bug "table index is nil"

v2.0:

-   Update to Legion pre-patch

v1.3:

-   Initial release with shared code base from [ElvUI_SmartQuestTracker](http://wow.curseforge.com/addons/elvui_smartquesttracker)
-   Fixes timing issues, that may occurs, when switching areas. (In preparation for Legion pre patch)
Adds Ace3 dependencies in libs folder
