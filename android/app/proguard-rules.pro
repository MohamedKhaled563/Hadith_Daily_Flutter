# Gson relies on generic type information at runtime (e.g. via TypeToken).
# R8 strips generic signatures by default, which breaks
# flutter_local_notifications' persistence of scheduled notifications
# (java.lang.IllegalStateException: TypeToken must be created with a type argument).
-keepattributes Signature
-keepattributes *Annotation*

-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
