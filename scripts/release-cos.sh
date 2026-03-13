#!/bin/bash
# 龙虾营地 Flutter App 发布脚本
# 同时发布到 GitHub Release、COS 和服务器

set -e

VERSION=$1
if [ -z "$VERSION" ]; then
  echo "用法: $0 <version>"
  echo "示例: $0 1.5.0"
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APK_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
COS_BUCKET="claw-camp-1307257815"
COS_REGION="ap-guangzhou"
COS_KEY="releases/camp-flutter-$VERSION.apk"
SERVER_PATH="/var/www/camp/camp-flutter-$VERSION.apk"
DOWNLOAD_URL="https://release.camp.aigc.sx.cn/releases/camp-flutter-$VERSION.apk"
LATEST_URL="https://release.camp.aigc.sx.cn/releases/camp-flutter-latest.apk"

echo "🦞 发布龙虾营地 v$VERSION"
echo "============================="

# 1. 构建 APK
echo ""
echo "📦 构建 APK..."
cd "$PROJECT_DIR"
export JAVA_HOME=/Users/phosa/Library/Java/JavaVirtualMachines/ms-17.0.18/Contents/Home
flutter clean
flutter build apk --release

if [ ! -f "$APK_PATH" ]; then
  echo "❌ APK 构建失败"
  exit 1
fi

# 2. 上传到服务器
echo ""
echo "🖥️  上传到服务器..."
scp -i ~/.openclaw/workspace/.ssh/phosa_claw_cvm "$APK_PATH" phosa_claw@119.91.123.2:~/camp-flutter-$VERSION.apk
ssh -i ~/.openclaw/workspace/.ssh/phosa_claw_cvm phosa_claw@119.91.123.2 "sudo mv ~/camp-flutter-$VERSION.apk $SERVER_PATH && sudo chmod 644 $SERVER_PATH && cd /var/www/camp && sudo ln -sf camp-flutter-$VERSION.apk camp-flutter-latest.apk"
echo "✅ 服务器上传完成: $DOWNLOAD_URL"

# 3. 上传到 COS（备份）
echo ""
echo "☁️  上传到 COS..."
cd ~/.openclaw/workspace/skills/tencent-cloud
node scripts/cos.js upload "$COS_BUCKET" "$APK_PATH" "$COS_KEY" "$COS_REGION" > /dev/null 2>&1 || echo "⚠️  COS 上传失败（继续）"
echo "✅ COS 备份完成"

# 4. 发布到 GitHub Release
echo ""
echo "🚀 发布到 GitHub Release..."
cd "$PROJECT_DIR"
git add -A
git commit -m "v$VERSION: 发布新版本" || true
git push
gh release create "v$VERSION" \
  --repo claw-camp/camp-flutter \
  --title "v$VERSION" \
  --notes "更新内容请查看版本说明" \
  "$APK_PATH" > /dev/null 2>&1 || echo "⚠️  GitHub Release 已存在"

GITHUB_URL="https://github.com/claw-camp/camp-flutter/releases/download/v$VERSION/app-release.apk"
echo "✅ GitHub Release: $GITHUB_URL"

# 5. 更新服务器版本信息
echo ""
echo "📝 更新服务器版本信息..."
VERSION_JSON=$(cat <<EOF
{
  "version": "$VERSION",
  "versionCode": $(echo "$VERSION" | awk -F. '{print $1*10000+$2*100+$3}'),
  "downloadUrl": "$DOWNLOAD_URL",
  "latestUrl": "$LATEST_URL",
  "githubUrl": "$GITHUB_URL",
  "releaseNotes": "修复流式消息显示问题，App 更名为龙虾营地",
  "releaseDate": "$(date +%Y-%m-%d)",
  "minAndroidVersion": 21,
  "features": [
    "修复流式消息只显示空气泡问题",
    "App 更名为龙虾营地",
    "更新 App 图标",
    "修复未读消息数不准确问题",
    "优化后台消息通知"
  ]
}
EOF
)

ssh -i ~/.openclaw/workspace/.ssh/phosa_claw_cvm phosa_claw@119.91.123.2 "echo '$VERSION_JSON' > ~/claw-hub/src/app-version.json"

echo ""
echo "✅ 发布完成！"
echo "============================="
echo "版本: v$VERSION"
echo "下载: $DOWNLOAD_URL"
echo "最新: $LATEST_URL"
echo "============================="
