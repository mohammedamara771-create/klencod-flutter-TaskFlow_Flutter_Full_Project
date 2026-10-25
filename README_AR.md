# TaskFlow - مشروع Flutter كامل

تطبيق عربي لإدارة المهام، بواجهة داكنة، وإضافة/تعديل/حذف المهام، وتصنيفها حسب الأولوية، والبحث والتصفية، وإحصائيات الإنجاز، وحفظ محلي على الهاتف.

## البناء عبر Klencod / GitHub Actions
1. ارفع جميع محتويات هذا المجلد إلى جذر مستودع GitHub (بحيث يظهر `pubspec.yaml` في الجذر).
2. تأكد أن ملف `lib/main.dart` موجود وغير فارغ.
3. من تبويب Actions شغّل `Build TaskFlow APK` أو ادفع commit جديدًا إلى `main`.
4. بعد نجاح البناء افتح نتيجة التشغيل، ثم نزّل artifact باسم `taskflow-release-apk`.

الـ workflow ينفّذ `flutter create --platforms=android --org com.taskflow .` لتوليد ملفات Android/Gradle المتوافقة مع نسخة Flutter المثبتة، ثم يجلب الحزم ويبني APK. هذا يعالج مشكلة عدم العثور على `dev.flutter.flutter-plugin-loader` في مشروع Android قديم أو ناقص.

## تشغيل محلي
```bash
flutter pub get
flutter create --platforms=android --org com.taskflow .
flutter build apk --release
```
