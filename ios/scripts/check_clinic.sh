#!/bin/sh
# فحص قبل بناء آيفون: إعدادات Xcode (المعرّف والاسم والأصول) لازم تكون لنفس العيادة
# اللي في ملف الإعدادات (--dart-define-from-file)، عشان ما تطلع عيادة بهوية عيادة ثانية.
# ونسخة الإنتاج (Archive) ما تنبني إلا بملف عيادة صريح.

fail() {
  echo "error: $1"
  exit 1
}

# القيم اللي وصلت من ملف العيادة (DART_DEFINES: كل قيمة مشفرة base64 ومفصولة بفاصلة)
FILE_ID=""
FILE_BUNDLE=""
FILE_NAME=""
OLD_IFS="$IFS"
IFS=','
for encoded in $DART_DEFINES; do
  decoded=$(printf '%s' "$encoded" | base64 --decode 2>/dev/null || printf '%s' "$encoded" | base64 -D 2>/dev/null)
  case "$decoded" in
    CLINIC_ID=*) FILE_ID="${decoded#CLINIC_ID=}" ;;
    CLINIC_IOS_BUNDLE_ID=*) FILE_BUNDLE="${decoded#CLINIC_IOS_BUNDLE_ID=}" ;;
    CLINIC_APP_NAME=*) FILE_NAME="${decoded#CLINIC_APP_NAME=}" ;;
  esac
done
IFS="$OLD_IFS"

if [ -n "$FILE_ID" ]; then
  [ "$FILE_ID" = "$CLINIC_ID" ] ||
    fail "ملف الإعدادات لعيادة \"$FILE_ID\" بس Xcode مجهز لعيادة \"$CLINIC_ID\". شغّل: python3 tool/clinic.py use $FILE_ID"
  [ "$FILE_BUNDLE" = "$CLINIC_IOS_BUNDLE_ID" ] && [ "$FILE_NAME" = "$CLINIC_DISPLAY_NAME" ] ||
    fail "ملف العيادة \"$FILE_ID\" تغيّر بعد تجهيز Xcode. شغّل: python3 tool/clinic.py use $FILE_ID"
else
  # بدون ملف: مسموح وقت التطوير بس، وبإعدادات عيادتي (demo)
  [ "$ACTION" != "install" ] ||
    fail "نسخة الإنتاج لازم تنبني بملف العيادة: python3 tool/clinic.py build <id> ipa"
  [ "$CLINIC_ID" = "demo" ] ||
    fail "التشغيل بدون ملف ياخذ إعدادات عيادتي، بس Xcode مجهز لعيادة \"$CLINIC_ID\". حدد ملفها (--dart-define-from-file=clinics/$CLINIC_ID/config.json) أو شغّل: python3 tool/clinic.py use demo"
fi

[ "$PRODUCT_BUNDLE_IDENTIFIER" = "$CLINIC_IOS_BUNDLE_ID" ] ||
  fail "معرّف التطبيق \"$PRODUCT_BUNDLE_IDENTIFIER\" غير معرّف العيادة \"$CLINIC_IOS_BUNDLE_ID\""

echo "العيادة: $CLINIC_ID · $CLINIC_DISPLAY_NAME · $PRODUCT_BUNDLE_IDENTIFIER"
