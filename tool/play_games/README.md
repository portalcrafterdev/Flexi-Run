# Play Games achievements

`AchievementsMetadata.csv` is the bulk-import file for Play Console:
**Grow users > Play Games Services > Setup and management > Achievements >
Import achievements**.

Columns, in order, with no header row:

    Name, Description, Incremental value, Steps Needed, Initial State, Points, List Order

No commas are allowed inside Name or Description - the file is split on them.

## Icons

The twelve 512x512 PNGs here are generated, not drawn by hand:

    flutter test tool/generate_achievement_icons.dart

It writes the PNGs and `AchievementsIconsMappings.csv` into this folder, both
keyed off the achievement names in `tool/award_art.dart`, so a name changed in
one place cannot silently stop matching the other.

No icon carries text. They are rasterised by `flutter test`, which has no font
loaded, so a digit would come out as a blank box - and a badge with nothing
written on it works for a six year old and for every locale at once.

## Building the zip

Zip the two CSVs and the twelve PNGs together, flat: no subdirectories, and
nothing else in the archive. This README must stay out of it.

Two things that cannot be undone after publishing: an achievement's **type**
(incremental or standard) and its **initial state**. Everything else - name,
description, points, icon - stays editable.

## Why only one is incremental

A Play Games incremental achievement accumulates forever and cannot be reset,
so it can only ever model a lifetime total. Every "in a single run" achievement
here is therefore standard, unlocked at the moment the run meets the condition.
"Coin Hunter" is the one genuine lifetime count, and so the only one that shows
a progress bar.

## iOS

Game Center needs the same twelve entered in App Store Connect with their own
identifiers. There is no shared format between the two stores, so the IDs are
mapped per platform in the Dart layer.
