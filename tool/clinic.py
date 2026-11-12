#!/usr/bin/env python3
"""بناء تطبيق مستقل لكل عيادة من ملف إعداداتها (clinics/<id>/config.json).

  python3 tool/clinic.py check                     يفحص كل العيادات (الملفات، المعرّفات، الأيقونات)
  python3 tool/clinic.py use <id>                   يختار العيادة لبناء آيفون (Xcode)
  python3 tool/clinic.py run <id> [-d جهاز]          يشغّل تطبيق العيادة على الجوال (release)
  python3 tool/clinic.py build <id> <نوع> [...]       يبني تطبيق العيادة: apk | appbundle | ios | ipa
  python3 tool/clinic.py assets <id>                يولّد أيقونات العيادة وشاشة البداية من clinics/<id>/icon.png

كل عيادة مجلدها مستقل:
  clinics/<id>/config.json                          الهوية والمعرّفات والألوان
  clinics/<id>/icon.png                             الأيقونة الأصلية (1024×1024)
  clinics/<id>/ios/<id>.clinic.xcassets             أيقونة آيفون وشاشة البداية (ما ينبني إلا أصول العيادة المختارة)
  clinics/<id>/android/res/mipmap-*/ic_launcher.png  أيقونة أندرويد

أندرويد ياخذ العيادة من ملف الإعدادات نفسه وقت البناء (بدون أي خطوة).
آيفون يحتاج "use" قبل البناء (Xcode يقرأ المعرّف من ملف xcconfig)، وفيه فحص داخل البناء يوقفه
لو العيادة المختارة غير العيادة اللي في ملف الإعدادات.
"""
from __future__ import annotations

import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLINICS = ROOT / "clinics"
PBXPROJ = ROOT / "ios/Runner.xcodeproj/project.pbxproj"
XC_DEFAULT = ROOT / "ios/Flutter/ClinicDefault.xcconfig"
XC_SELECTED = ROOT / "ios/Flutter/ClinicSelected.xcconfig"
DEFAULT_ID = "demo"

KEYS = [
    "CLINIC_ID", "CLINIC_APP_NAME", "CLINIC_NAME_EN", "CLINIC_PHONE", "CLINIC_WHATSAPP", "CLINIC_SHARE_LINK", "CLINIC_STORE_URL",
    "CLINIC_MONOGRAM", "CLINIC_ACCENT", "CLINIC_ON_ACCENT", "CLINIC_IOS_BUNDLE_ID", "CLINIC_ANDROID_APP_ID",
    "CLINIC_SPLASH_COLOR",
]
ANDROID_ICON_SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}


class ClinicError(Exception):
    pass


def log(msg: str) -> None:
    print(f"▶ {msg}", flush=True)


# ───────────────────────── ملف العيادة

def config_path(cid: str) -> Path:
    return CLINICS / cid / "config.json"


def load(cid: str) -> dict:
    path = config_path(cid)
    if not path.exists():
        raise ClinicError(f"ما لقيت ملف العيادة: clinics/{cid}/config.json")
    data = json.loads(path.read_text(encoding="utf-8"))
    missing = [k for k in KEYS if not str(data.get(k, "")).strip()]
    if missing:
        raise ClinicError(f"ملف clinics/{cid} ناقص: {', '.join(missing)}")
    extra = sorted(set(data) - set(KEYS))
    if extra:
        raise ClinicError(f"مفاتيح غير معروفة في clinics/{cid}: {', '.join(extra)}")
    if data["CLINIC_ID"] != cid:
        raise ClinicError(f"CLINIC_ID في clinics/{cid} لازم يكون \"{cid}\" (والموجود \"{data['CLINIC_ID']}\")")
    if not re.fullmatch(r"[a-z][a-z0-9_]{1,30}", cid):
        raise ClinicError(f"معرّف العيادة \"{cid}\": حروف إنجليزية صغيرة وأرقام و_ بس")
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z0-9-]+)+", data["CLINIC_IOS_BUNDLE_ID"]):
        raise ClinicError(f"CLINIC_IOS_BUNDLE_ID في clinics/{cid} بصيغة غلط")
    if not re.fullmatch(r"[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+", data["CLINIC_ANDROID_APP_ID"]):
        raise ClinicError(f"CLINIC_ANDROID_APP_ID في clinics/{cid} بصيغة غلط")
    for key in ("CLINIC_ACCENT", "CLINIC_ON_ACCENT", "CLINIC_SPLASH_COLOR"):
        if not re.fullmatch(r"0x[fF]{2}[0-9a-fA-F]{6}", data[key]):
            raise ClinicError(f"{key} في clinics/{cid} لازم بصيغة 0xFFRRGGBB")
    if "//" in data["CLINIC_APP_NAME"]:
        raise ClinicError("CLINIC_APP_NAME ما يحتوي //")
    return data


def all_ids() -> list[str]:
    return sorted(p.name for p in CLINICS.iterdir() if p.is_dir() and not p.name.startswith("."))


# ───────────────────────── آيفون: اختيار العيادة (xcconfig)

def xcconfig(data: dict, note: str) -> str:
    return (
        f"// {note}\n"
        "// لا تعدّل يدوياً: يتولد من clinics/<id>/config.json بالأمر python3 tool/clinic.py\n"
        f"CLINIC_ID = {data['CLINIC_ID']}\n"
        f"CLINIC_IOS_BUNDLE_ID = {data['CLINIC_IOS_BUNDLE_ID']}\n"
        f"CLINIC_DISPLAY_NAME = {data['CLINIC_APP_NAME']}\n"
        "// أصول كل عيادة (الأيقونة وشاشة البداية) في clinics/<id>/ios/<id>.clinic.xcassets،\n"
        "// وما ينبني منها إلا أصول العيادة المختارة\n"
        "EXCLUDED_SOURCE_FILE_NAMES = *.clinic.xcassets\n"
        "INCLUDED_SOURCE_FILE_NAMES = $(CLINIC_ID).clinic.xcassets\n"
    )


def default_xcconfig_text() -> str:
    return xcconfig(load(DEFAULT_ID), "العيادة الافتراضية لبناء آيفون: Clinics App (demo)")


def use(cid: str) -> None:
    data = load(cid)
    check_assets(cid)
    if cid == DEFAULT_ID:
        XC_SELECTED.unlink(missing_ok=True)
    else:
        XC_SELECTED.write_text(xcconfig(data, f"العيادة المختارة لبناء آيفون: {cid} (ما يرتفع لـ GitHub)"), encoding="utf-8")
    log(f"آيفون: العيادة المختارة {cid} ({data['CLINIC_IOS_BUNDLE_ID']})")


# ───────────────────────── أصول العيادة (الأيقونة وشاشة البداية)

def catalog(cid: str) -> Path:
    return CLINICS / cid / "ios" / f"{cid}.clinic.xcassets"


def check_assets(cid: str) -> None:
    c = catalog(cid)
    need = [
        CLINICS / cid / "icon.png",
        c / "Contents.json",
        c / "AppIcon.appiconset/Contents.json",
        c / "LaunchBackground.colorset/Contents.json",
        c / "LaunchImage.imageset/Contents.json",
        *[CLINICS / cid / f"android/res/mipmap-{d}/ic_launcher.png" for d in ANDROID_ICON_SIZES],
    ]
    missing = [str(p.relative_to(ROOT)) for p in need if not p.exists()]
    if missing:
        raise ClinicError(f"أصول العيادة {cid} ناقصة (شغّل: python3 tool/clinic.py assets {cid}):\n  " + "\n  ".join(missing))
    if pbx_ids(cid)[0] not in PBXPROJ.read_text():
        raise ClinicError(f"أصول آيفون للعيادة {cid} مو مسجلة في مشروع Xcode (شغّل: python3 tool/clinic.py assets {cid})")


def _resize(src: Path, dst: Path, size: int, rgb: bool = False) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    try:
        from PIL import Image  # type: ignore
    except ImportError:
        Image = None
    if Image is not None:
        img = Image.open(src)
        if rgb:
            # أيقونة آيفون بدون شفافية
            bg = Image.new("RGB", img.size, (255, 255, 255))
            bg.paste(img.convert("RGBA"), mask=img.convert("RGBA").split()[3])
            img = bg
        img.resize((size, size), Image.LANCZOS).save(dst, "PNG")
        return
    if shutil.which("sips"):
        subprocess.run(["sips", "-z", str(size), str(size), str(src), "--out", str(dst)], check=True, capture_output=True)
        return
    raise ClinicError("أحتاج Pillow عشان أجهز الأيقونات: pip3 install pillow")


def _json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def assets(cid: str, force: bool = False) -> None:
    data = load(cid)
    icon = CLINICS / cid / "icon.png"
    if not icon.exists():
        raise ClinicError(f"حط أيقونة العيادة (1024×1024) في clinics/{cid}/icon.png")
    c = catalog(cid)
    info = {"info": {"author": "xcode", "version": 1}}
    if force or not (c / "AppIcon.appiconset/Contents.json").exists():
        _json(c / "Contents.json", info)
        _resize(icon, c / "AppIcon.appiconset/icon-1024.png", 1024, rgb=True)
        _json(c / "AppIcon.appiconset/Contents.json", {
            "images": [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
            **info,
        })
        log(f"آيفون: أيقونة {cid}")
    # شاشة البداية: لون العيادة (والصورة فاضية لين يتوفر شعار)
    argb = int(data["CLINIC_SPLASH_COLOR"], 16)
    comp = {k: f"{((argb >> s) & 0xFF) / 255:.3f}" for k, s in (("red", 16), ("green", 8), ("blue", 0))}
    _json(c / "LaunchBackground.colorset/Contents.json", {
        "colors": [{"color": {"color-space": "srgb", "components": {"alpha": "1.000", **comp}}, "idiom": "universal"}],
        **info,
    })
    if not (c / "LaunchImage.imageset/Contents.json").exists():
        shutil.copytree(catalog(DEFAULT_ID) / "LaunchImage.imageset", c / "LaunchImage.imageset")
    for d, size in ANDROID_ICON_SIZES.items():
        dst = CLINICS / cid / f"android/res/mipmap-{d}/ic_launcher.png"
        if force or not dst.exists():
            _resize(icon, dst, size)
    log(f"أندرويد: أيقونة {cid}")
    register(cid)
    check_assets(cid)


# ───────────────────────── مشروع Xcode

def _hex_id(text: str) -> str:
    return hashlib.md5(text.encode()).hexdigest()[:24].upper()


def pbx_ids(cid: str) -> tuple[str, str]:
    return _hex_id(f"clinic-catalog-ref-{cid}"), _hex_id(f"clinic-catalog-build-{cid}")


def _insert_after(text: str, anchor: str, line: str) -> str:
    i = text.find(anchor)
    if i < 0:
        raise ClinicError(f"ما لقيت في مشروع Xcode: {anchor.strip()}")
    j = text.index("\n", i) + 1
    return text[:j] + line + text[j:]


def register(cid: str) -> None:
    """يسجّل أصول آيفون للعيادة في المشروع (مرة وحدة لكل عيادة)"""
    ref, build = pbx_ids(cid)
    text = PBXPROJ.read_text()
    if ref in text:
        return
    name = f"{cid}.clinic.xcassets"
    text = _insert_after(text, "/* Begin PBXBuildFile section */",
                         f"\t\t{build} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};\n")
    text = _insert_after(text, "/* Begin PBXFileReference section */",
                         f"\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; "
                         f"name = {name}; path = ../clinics/{cid}/ios/{name}; sourceTree = SOURCE_ROOT; }};\n")
    text = _insert_after(text, "\t\t\t\t97C146FD1CF9000F007C117D /* Assets.xcassets */,", f"\t\t\t\t{ref} /* {name} */,\n")
    text = _insert_after(text, "\t\t\t\t97C146FE1CF9000F007C117D /* Assets.xcassets in Resources */,",
                         f"\t\t\t\t{build} /* {name} in Resources */,\n")
    PBXPROJ.write_text(text)
    log(f"Xcode: سجلت أصول {cid}")


# ───────────────────────── الفحص

def check() -> None:
    ids = all_ids()
    seen: dict[str, dict[str, str]] = {"CLINIC_IOS_BUNDLE_ID": {}, "CLINIC_ANDROID_APP_ID": {}, "CLINIC_APP_NAME": {}}
    for cid in ids:
        data = load(cid)
        check_assets(cid)
        for key, owners in seen.items():
            if data[key] in owners:
                raise ClinicError(f"{key} \"{data[key]}\" مكرر بين {owners[data[key]]} و{cid}")
            owners[data[key]] = cid
    if DEFAULT_ID not in ids:
        raise ClinicError("عيادة demo لازم تكون موجودة (هي الافتراضية وقت التطوير)")
    if XC_DEFAULT.read_text(encoding="utf-8") != default_xcconfig_text():
        raise ClinicError("ios/Flutter/ClinicDefault.xcconfig ما يطابق clinics/demo (شغّل: python3 tool/clinic.py default)")
    log(f"العيادات سليمة: {', '.join(ids)}")


# ───────────────────────── البناء والتشغيل

def flutter(args: list[str]) -> None:
    log("flutter " + " ".join(args))
    sys.exit(subprocess.run(["flutter", *args], cwd=ROOT).returncode)


def main(argv: list[str]) -> None:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return
    cmd, rest = argv[0], argv[1:]
    if cmd == "check":
        check()
    elif cmd == "default":
        XC_DEFAULT.write_text(default_xcconfig_text(), encoding="utf-8")
        log("ClinicDefault.xcconfig من clinics/demo")
    elif cmd == "use" and len(rest) == 1:
        use(rest[0])
    elif cmd == "assets" and rest:
        assets(rest[0], force="--force" in rest)
    elif cmd == "run" and rest:
        use(rest[0])
        flutter(["run", "--release", f"--dart-define-from-file=clinics/{rest[0]}/config.json", *rest[1:]])
    elif cmd == "build" and len(rest) >= 2:
        cid, kind = rest[0], rest[1]
        if kind not in ("apk", "appbundle", "ios", "ipa"):
            raise ClinicError("نوع البناء: apk أو appbundle أو ios أو ipa")
        use(cid)
        flutter(["build", kind, "--release", f"--dart-define-from-file=clinics/{cid}/config.json", *rest[2:]])
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except ClinicError as e:
        print(f"✗ {e}", file=sys.stderr)
        sys.exit(1)
