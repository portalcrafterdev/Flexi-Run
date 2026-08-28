# Keep rules for the release build, where R8 shrinks and renames everything it
# cannot prove is used.
#
# The rule of thumb: anything looked up by name at runtime is invisible to R8.
# It sees no reference, decides the class is dead, and removes it - and the
# failure only ever shows up in a release build, which is the one nobody runs
# until they are shipping.

# WorkManager and Room.
#
# This is not optional: without it the app dies on launch with
#
#     Failed to create an instance of androidx.work.impl.WorkDatabase
#
# before a single frame is drawn. Room builds its database by loading a
# generated "<Name>_Impl" class by string, so nothing in the code ever
# mentions it. androidx.startup runs WorkManager's initializer from a
# ContentProvider at process start, so the crash takes the whole app with it.
#
# WorkManager arrives transitively with Google Mobile Ads rather than being
# asked for directly, which is why nothing in this project names it.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-keep class androidx.startup.** { *; }
-dontwarn androidx.work.**

# Room writes these annotations into generated code and reads them back.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

# Google Mobile Ads. The SDK instantiates adapters and mediation classes by
# name, so the same reasoning applies.
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Play Games. The sign-in and achievements calls cross into Play Services,
# which resolves several of its entry points reflectively.
-keep class com.google.android.gms.games.** { *; }
-dontwarn com.google.android.gms.games.**

# Flutter plugin channels are resolved by name from Dart, so the registrant
# and the plugin classes it names must survive.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
