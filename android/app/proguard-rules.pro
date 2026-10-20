# Pigeon/JNI resolves these Kotlin classes by their original JVM names.
# See https://flutter.googlesource.com/mirrors/packages/+/refs/heads/main/packages/pigeon/native_interop_guide.md
# Android release R8 must preserve both names and members used via reflection.
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
