# google_mlkit_text_recognition references the Chinese/Devanagari/Japanese/Korean
# recognizers, but FOORA only bundles the Latin one (Vietnamese receipts).
# Without these, R8 fails the release build on the missing classes.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
