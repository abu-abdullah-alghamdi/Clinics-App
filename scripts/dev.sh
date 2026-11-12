#!/usr/bin/env bash
# =============================================================
#  عيادتي — تشغيل التطبيق وتحديثه على Xcode
#
#  ./scripts/dev.sh run     تجهيز المشروع وفتحه في Xcode وتشغيله
#  ./scripts/dev.sh update  سحب آخر نسخة من GitHub ثم إعادة البناء والتشغيل
#  ./scripts/dev.sh watch   مراقبة GitHub: أي تحديث جديد يُسحب ويُشغّل تلقائياً
#  ./scripts/dev.sh sim     تشغيل سريع على المحاكي من الطرفية (مع Hot Reload)
#
#  العيادة: إعداداتها من clinics/<id>/config.json (الافتراضية demo)
#  لعيادة ثانية: CLINIC=<id> ./scripts/dev.sh run
# =============================================================
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP_NAME="عيادتي"
WATCH_EVERY="${WATCH_EVERY:-30}"   # كل كم ثانية يتحقق من وجود تحديث
CLINIC="${CLINIC:-demo}"
CLINIC_FILE="clinics/$CLINIC/config.json"

say()  { printf "\n\033[1;32m▶ %s\033[0m\n" "$*"; }
warn() { printf "\n\033[1;33m! %s\033[0m\n" "$*"; }
die()  { printf "\n\033[1;31m✗ %s\033[0m\n" "$*"; exit 1; }

check_tools() {
  [[ "$(uname)" == "Darwin" ]] || die "هذا السكربت يشتغل على جهاز ماك فقط."
  command -v flutter >/dev/null || die "Flutter غير مثبت. ثبّته من flutter.dev ثم أعد المحاولة."
  command -v xcodebuild >/dev/null || die "Xcode غير مثبت. ثبّته من App Store."
}

# مجلدا iOS وAndroid محفوظين في المشروع بإعداداتهم (tool/native_setup.py)،
# فالسكربت ما يولّدهم ولا يعدّل عليهم. المكتبات عن طريق Swift Package Manager (بدون CocoaPods).
prepare() {
  if [[ -f ios/Podfile ]] && ! git ls-files --error-unmatch ios/Podfile >/dev/null 2>&1; then
    warn "فيه ملفات CocoaPods قديمة من النسخة السابقة وبتخرب البناء. احذفها مرة وحدة:"
    echo "  rm -rf ios/Podfile ios/Podfile.lock ios/Pods ios/.symlinks"
    die "احذفها وأعد التشغيل."
  fi
  [[ -f "$CLINIC_FILE" ]] || die "ما لقيت إعدادات العيادة: $CLINIC_FILE"
  say "تحميل الحزم"
  flutter pub get
  # إعدادات العيادة لـ Xcode (زر Run يقرأها من هنا)
  say "إعدادات العيادة: $CLINIC"
  # آيفون: المعرّف والاسم والأيقونة للعيادة المختارة
  python3 tool/clinic.py use "$CLINIC"
  flutter build ios --config-only --debug --dart-define-from-file="$CLINIC_FILE"
}

boot_simulator() {
  open -a Simulator || true
  # يشغّل أول آيفون متاح إذا ما فيه محاكي شغال
  if ! xcrun simctl list devices booted | grep -q "Booted"; then
    local dev
    dev="$(xcrun simctl list devices available | grep -E 'iPhone' | head -n1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
    [[ -n "$dev" ]] && xcrun simctl boot "$dev" 2>/dev/null || true
  fi
}

# يفتح المشروع في Xcode ويضغط Run (يوقف التشغيل السابق أول)
xcode_run() {
  say "فتح المشروع في Xcode"
  open "ios/Runner.xcworkspace"
  boot_simulator
  say "تشغيل التطبيق داخل Xcode"
  osascript <<'OSA' || warn "ما قدرت أضغط Run تلقائياً. اضغط ▶ في Xcode (أو Cmd+R)."
tell application "Xcode"
  activate
  set ws to missing value
  repeat 60 times
    try
      set ws to workspace document "Runner.xcworkspace"
      if loaded of ws is true then exit repeat
    end try
    delay 1
  end repeat
  if ws is missing value then error "Xcode workspace not ready"
  try
    stop ws
  end try
  delay 1
  run ws
end tell
OSA
  say "تم. لو Xcode طلب جهاز، اختر iPhone من القائمة اللي فوق مرة وحدة وبيتذكره."
}

has_remote() { git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; }

pull_latest() {
  has_remote || die "المشروع مو مربوط بمستودع GitHub. شوف ملف README (خطوة الربط)."
  say "سحب آخر نسخة"
  if ! git diff --quiet || ! git diff --cached --quiet; then
    warn "عندك تعديلات محلية، بحفظها مؤقتاً (git stash) قبل السحب."
    git stash push -u -m "auto-stash $(date '+%F %T')" >/dev/null
  fi
  git pull --ff-only
}

# فيه تحديث جديد بس إذا GitHub عنده commits مو موجودة عندك
# (لو نسختك متقدمة على GitHub ما يعتبرها تحديث، وما يعيد التشغيل)
is_behind() {
  git fetch --quiet 2>/dev/null || return 1
  [[ "$(git rev-list --count HEAD..'@{u}')" -gt 0 ]]
}

cmd_run()    { check_tools; prepare; xcode_run; }
cmd_update() { check_tools; pull_latest; prepare; xcode_run; }
cmd_sim() {
  check_tools; prepare; boot_simulator
  local udid
  udid="$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -n1)"
  [[ -n "$udid" ]] || die "ما لقيت محاكي شغال. افتح Simulator وشغّل أي iPhone."
  flutter run -d "$udid" --dart-define-from-file="$CLINIC_FILE"
}

cmd_watch() {
  check_tools
  has_remote || die "المشروع مو مربوط بمستودع GitHub. شوف ملف README (خطوة الربط)."
  say "وضع المراقبة شغال: أي تحديث يُرفع على GitHub بيُسحب ويتشغل تلقائياً (Ctrl+C للإيقاف)"
  cmd_run
  while true; do
    sleep "$WATCH_EVERY"
    if is_behind; then
      say "وصل تحديث جديد: $(git log --oneline -1 '@{u}')"
      pull_latest
      prepare
      xcode_run
      command -v osascript >/dev/null && osascript -e "display notification \"تم تحديث التطبيق وتشغيله\" with title \"$APP_NAME\"" || true
    fi
  done
}

case "${1:-run}" in
  run)    cmd_run ;;
  update) cmd_update ;;
  watch)  cmd_watch ;;
  sim)    cmd_sim ;;
  *) echo "الاستخدام: $0 [run|update|watch|sim]"; exit 1 ;;
esac
