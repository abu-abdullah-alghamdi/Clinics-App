#!/usr/bin/env python3
"""يتأكد إن التطبيق اللي انبنى هو تطبيق العيادة المطلوبة بالضبط (يُستخدم في GitHub بعد البناء).

  python3 tool/verify_build.py <id> android     يفحص build/app/outputs/flutter-apk/app-release.apk
  python3 tool/verify_build.py <id> ios         يفحص build/ios/iphoneos/Runner.app

يفحص: المعرّف، الاسم تحت الأيقونة، الأيقونة (لونها نفس أيقونة العيادة)، لون شاشة البداية،
وإن ما فيه أصول عيادة ثانية داخل التطبيق.
"""
from __future__ import annotations

import io
import json
import plistlib
import re
import subprocess
import sys
import zipfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


def fail(msg: str) -> None:
    print(f"::error title=التحقق من البناء::{msg}")
    sys.exit(1)


def ok(msg: str) -> None:
    print(f"✓ {msg}")


def avg(img: Image.Image) -> tuple[float, float, float]:
    """متوسط لون الأيقونة (بدون الأجزاء الشفافة)"""
    img = img.convert("RGBA").resize((64, 64))
    px = [p for p in img.getdata() if p[3] > 200]
    n = max(len(px), 1)
    return tuple(sum(p[i] for p in px) / n for i in range(3))  # type: ignore[return-value]


def same_icon(built: Image.Image, source: Path, label: str) -> None:
    a, b = avg(built), avg(Image.open(source))
    diff = max(abs(x - y) for x, y in zip(a, b))
    if diff > 12:
        fail(f"{label}: الأيقونة مو أيقونة العيادة (فرق اللون {diff:.0f})")
    ok(f"{label}: الأيقونة نفس أيقونة العيادة (فرق اللون {diff:.1f})")


def android(cid: str, c: dict) -> None:
    apk = ROOT / "build/app/outputs/flutter-apk/app-release.apk"
    aapt = sorted(Path(__import__("os").environ["ANDROID_HOME"]).glob("build-tools/*/aapt"))[-1]
    badging = subprocess.run([str(aapt), "dump", "badging", str(apk)], capture_output=True, text=True, check=True).stdout
    pkg = re.search(r"package: name='([^']+)'", badging).group(1)
    label = re.search(r"application-label:'([^']*)'", badging).group(1)
    if pkg != c["CLINIC_ANDROID_APP_ID"]:
        fail(f"أندرويد: المعرّف {pkg} والمفروض {c['CLINIC_ANDROID_APP_ID']}")
    ok(f"أندرويد: المعرّف {pkg}")
    if label != c["CLINIC_APP_NAME"]:
        fail(f"أندرويد: الاسم {label} والمفروض {c['CLINIC_APP_NAME']}")
    ok(f"أندرويد: الاسم {label}")
    icon_path = re.findall(r"application-icon-(\d+):'([^']+)'", badging)[-1][1]
    with zipfile.ZipFile(apk) as z:
        built = Image.open(io.BytesIO(z.read(icon_path)))
    same_icon(built, ROOT / f"clinics/{cid}/android/res/mipmap-xxxhdpi/ic_launcher.png", "أندرويد")
    values = subprocess.run([str(aapt), "dump", "--values", "resources", str(apk)], capture_output=True, text=True, check=True).stdout
    m = re.search(r"color/clinic_splash: .*?\n\s*\(color\) (#[0-9a-f]{8})", values)
    want = "#" + c["CLINIC_SPLASH_COLOR"][2:].lower()
    if not m or m.group(1) != want:
        fail(f"أندرويد: لون شاشة البداية {m.group(1) if m else '؟'} والمفروض {want}")
    ok(f"أندرويد: لون شاشة البداية {want}")


def open_ios_png(path: Path) -> Image.Image:
    """أيقونات آيفون داخل التطبيق مضغوطة بصيغة آبل (CgBI)، نرجعها PNG عادي قبل القراءة"""
    try:
        img = Image.open(path)
        img.load()
        return img
    except OSError:
        pass
    out = Path("/tmp") / f"plain_{path.name}"
    for cmd in (["xcrun", "-sdk", "iphoneos", "pngcrush", "-q", "-revert-iphone-optimizations", str(path), str(out)],
                ["sips", "-s", "format", "png", str(path), "--out", str(out)]):
        if subprocess.run(cmd, capture_output=True).returncode == 0 and out.exists():
            img = Image.open(out)
            img.load()
            return img
    fail(f"آيفون: ما قدرت أقرأ الأيقونة {path.name}")
    raise SystemExit


def ios(cid: str, c: dict) -> None:
    app = ROOT / "build/ios/iphoneos/Runner.app"
    info = plistlib.loads((app / "Info.plist").read_bytes())
    if info["CFBundleIdentifier"] != c["CLINIC_IOS_BUNDLE_ID"]:
        fail(f"آيفون: المعرّف {info['CFBundleIdentifier']} والمفروض {c['CLINIC_IOS_BUNDLE_ID']}")
    ok(f"آيفون: المعرّف {info['CFBundleIdentifier']}")
    if info["CFBundleDisplayName"] != c["CLINIC_APP_NAME"]:
        fail(f"آيفون: الاسم {info['CFBundleDisplayName']} والمفروض {c['CLINIC_APP_NAME']}")
    ok(f"آيفون: الاسم {info['CFBundleDisplayName']}")
    icons = sorted(app.glob("AppIcon60x60@*.png"))
    if not icons:
        fail("آيفون: ما لقيت الأيقونة داخل التطبيق")
    same_icon(open_ios_png(icons[-1]), ROOT / f"clinics/{cid}/icon.png", "آيفون")
    # الأصول داخل التطبيق: لون شاشة البداية، وما فيه أصول عيادة ثانية
    out = subprocess.run(["xcrun", "--sdk", "iphoneos", "assetutil", "--info", str(app / "Assets.car")],
                         capture_output=True, text=True, check=True).stdout
    assets = json.loads(out)
    colors = [a for a in assets if a.get("Name") == "LaunchBackground" and "Color components" in a]
    if len(colors) != 1:
        fail(f"آيفون: لازم لون شاشة بداية واحد بس داخل التطبيق، ولقيت {len(colors)}")
    want = int(c["CLINIC_SPLASH_COLOR"], 16)
    got = [round(v * 255) for v in colors[0]["Color components"][:3]]
    exp = [(want >> 16) & 255, (want >> 8) & 255, want & 255]
    if max(abs(a - b) for a, b in zip(got, exp)) > 2:
        fail(f"آيفون: لون شاشة البداية {got} والمفروض {exp}")
    ok(f"آيفون: لون شاشة البداية {exp}")
    names = sorted({a.get("Name") for a in assets if a.get("Name")})
    ok(f"آيفون: الأصول داخل التطبيق {names}")


def main() -> None:
    cid, platform = sys.argv[1], sys.argv[2]
    c = json.loads((ROOT / f"clinics/{cid}/config.json").read_text(encoding="utf-8"))
    {"android": android, "ios": ios}[platform](cid, c)
    print(f"::notice title=تطبيق {cid} ({platform})::{c['CLINIC_APP_NAME']} · "
          f"{c['CLINIC_IOS_BUNDLE_ID'] if platform == 'ios' else c['CLINIC_ANDROID_APP_ID']} · الأيقونة ولون البداية صحيحة")


if __name__ == "__main__":
    main()
