# ProGuard rules for SVG Builder (Drift, SQLite, XML, File Picker)

# Drift & SQLite
-keep class androidx.sqlite.db.** { *; }
-keep class io.requery.android.database.sqlite.** { *; }
-keepclassmembers class * extends com.simonmittag.cryptoutils.Crypt { *; }
-keepclassmembers class * extends com.simonmittag.cryptoutils.PBKDF2 { *; }

# Keep Drift table & DAO definitions
-keep class * extends drift.GeneratedDatabase { *; }
-keep class * extends drift.Table { *; }
-keep class * extends drift.Dao { *; }
-keep class * implements drift.Insertable { *; }

# Drift companion classes
-keep class * extends drift.UpdateCompanion { *; }

# XML serialization
-keep class org.xml.** { *; }
-keep class org.w3c.dom.** { *; }

# SharePlus & FilePicker
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }
