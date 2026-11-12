#!/usr/bin/env python3
"""ضبط مجلدي iOS وAndroid بنفس إعدادات التطبيق الحالية.

ينفّذ بالضبط اللي كان scripts/dev.sh يسويه على الماك وقت كل تشغيل (بـ PlistBuddy)،
بس مرة وحدة وتنحفظ النتيجة في المشروع. آمن لو انعاد تشغيله (ما يكرر شي).

  python3 tool/native_setup.py
"""
from __future__ import annotations

import plistlib
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# الاسم تحت الأيقونة من ملف العيادة (clinics/<id>/config.json): آيفون من xcconfig، وأندرويد من build.gradle.kts
IOS_APP_NAME = "$(CLINIC_DISPLAY_NAME)"
ANDROID_APP_NAME = "@string/app_name"
IOS_MIN = "17.0"
CALENDAR_TEXT = "نضيف موعدك لتقويم جوالك مع تذكير قبله"
CONTACTS_TEXT = "يستخدمه التقويم لاقتراح العناوين"


def log(msg: str) -> None:
    print(f"▶ {msg}")


# ───────────────────────── iOS

def ios_info_plist() -> None:
    path = ROOT / "ios/Runner/Info.plist"
    with path.open("rb") as f:
        p = plistlib.load(f)
    p["CFBundleDisplayName"] = IOS_APP_NAME
    p["CFBundleDevelopmentRegion"] = "ar"
    p["CFBundleLocalizations"] = ["ar"]
    # التطبيق فاتح دايماً (حتى لو الجوال على الوضع الداكن)
    p["UIUserInterfaceStyle"] = "Light"
    # أذونات: إضافة الموعد للتقويم (نص يطلع للمستخدم وقت الطلب)
    for key in ("NSCalendarsUsageDescription", "NSCalendarsWriteOnlyAccessUsageDescription", "NSCalendarsFullAccessUsageDescription"):
        p[key] = CALENDAR_TEXT
    p["NSContactsUsageDescription"] = CONTACTS_TEXT
    with path.open("wb") as f:
        plistlib.dump(p, f, sort_keys=False)
    log("iOS Info.plist: الاسم، العربية، الوضع الفاتح، أذونات التقويم")


def ios_deployment_target() -> None:
    pbx = ROOT / "ios/Runner.xcodeproj/project.pbxproj"
    text = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;", f"IPHONEOS_DEPLOYMENT_TARGET = {IOS_MIN};", pbx.read_text())
    pbx.write_text(text)
    info = ROOT / "ios/Flutter/AppFrameworkInfo.plist"
    if info.exists():
        with info.open("rb") as f:
            p = plistlib.load(f)
        if "MinimumOSVersion" in p:
            p["MinimumOSVersion"] = IOS_MIN
            with info.open("wb") as f:
                plistlib.dump(p, f, sort_keys=False)
    log(f"iOS: أقل إصدار {IOS_MIN}")


def ios_podfile() -> None:
    """المكتبات كلها Swift Packages (بدون CocoaPods). لو فيه Podfile (نسخة فلاتر قديمة) نضبط أقل إصدار فيه"""
    podfile = ROOT / "ios/Podfile"
    if not podfile.exists():
        log("iOS: المكتبات عن طريق Swift Package Manager (بدون Podfile)")
        return
    text = podfile.read_text()
    text = re.sub(r"^#? *platform :ios.*$", f"platform :ios, '{IOS_MIN}'", text, flags=re.M)
    marker = 'c.build_settings["IPHONEOS_DEPLOYMENT_TARGET"]'
    if marker not in text:
        text = text.replace(
            "flutter_additional_ios_build_settings(target)\n",
            "flutter_additional_ios_build_settings(target)\n"
            f'    target.build_configurations.each {{ |c| c.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "{IOS_MIN}" }}\n',
        )
    podfile.write_text(text)
    log("iOS Podfile: أقل إصدار للمشروع والمكتبات")


# ───────────────────────── Android

NOTIF_RECEIVERS = """        <!-- التذكيرات المجدولة (flutter_local_notifications) -->
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""

PERMISSIONS = """    <!-- التذكيرات (أندرويد 13 وفوق يطلب إذن الإشعارات) -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
"""

QUERIES = """        <!-- فتح الروابط والاتصال وواتساب والخرائط (url_launcher) -->
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.DIAL" />
            <data android:scheme="tel" />
        </intent>
"""


def android_manifest() -> None:
    path = ROOT / "android/app/src/main/AndroidManifest.xml"
    text = path.read_text()
    text = re.sub(r'android:label="[^"]*"', f'android:label="{ANDROID_APP_NAME}"', text, count=1)
    if "android:supportsRtl" not in text:
        text = text.replace("<application\n", '<application\n        android:supportsRtl="true"\n', 1)
    if "POST_NOTIFICATIONS" not in text:
        text = re.sub(r"(<manifest[^>]*>\n)", r"\1" + PERMISSIONS.replace("\\", "\\\\"), text, count=1)
    if "ScheduledNotificationReceiver" not in text:
        text = text.replace("    </application>", NOTIF_RECEIVERS + "    </application>", 1)
    if 'android:scheme="tel"' not in text:
        if "<queries>" in text:
            text = text.replace("<queries>\n", "<queries>\n" + QUERIES, 1)
        else:
            text = text.replace("</manifest>", "    <queries>\n" + QUERIES + "    </queries>\n</manifest>", 1)
    path.write_text(text)
    log("Android: الاسم، الاتجاه، أذونات التذكير، فتح الروابط")


def android_gradle() -> None:
    """flutter_local_notifications يحتاج desugaring"""
    kts = ROOT / "android/app/build.gradle.kts"
    groovy = ROOT / "android/app/build.gradle"
    path = kts if kts.exists() else groovy
    text = path.read_text()
    if "desugar_jdk_libs" not in text:
        if path == kts:
            text = text.replace("compileOptions {\n", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true\n", 1)
            text += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        else:
            text = text.replace("compileOptions {\n", "compileOptions {\n        coreLibraryDesugaringEnabled true\n", 1)
            text += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    path.write_text(text)
    log(f"Android {path.name}: desugaring للتذكيرات")


def android_light_only() -> None:
    """الوضع الفاتح دايماً: شاشة البداية الليلية نفس النهارية"""
    day = ROOT / "android/app/src/main/res/values/styles.xml"
    night = ROOT / "android/app/src/main/res/values-night/styles.xml"
    if night.exists() and day.exists():
        shutil.copy(day, night)
    log("Android: الوضع الفاتح دايماً")


def main() -> None:
    if not (ROOT / "ios/Runner/Info.plist").exists() or not (ROOT / "android/app/src/main/AndroidManifest.xml").exists():
        log("إنشاء مجلدي iOS وAndroid")
        subprocess.run(
            ["flutter", "create", "--platforms=ios,android", "--org", "com.clinicsapp", "--project-name", "clinics_app", "."],
            cwd=ROOT,
            check=True,
        )
    ios_info_plist()
    ios_deployment_target()
    ios_podfile()
    android_manifest()
    android_gradle()
    android_light_only()
    log("تم")


if __name__ == "__main__":
    main()
