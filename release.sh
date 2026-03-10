#!/bin/bash
# 龙虾营地 Flutter App 发布脚本
# 用法: ./release.sh [版本号]
# 示例: ./release.sh 1.1.9

set -e

# 配置
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PUBSPEC="$SCRIPT_DIR/pubspec.yaml"
REPO="claw-camp/camp-flutter"
SSH_KEY="$HOME/.openclaw/workspace/.ssh/phosa_claw_cvm"
SERVER_USER="phosa_claw@119.91.123.2"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 获取当前版本
get_current_version() {
    grep "^version:" "$PUBSPEC" | sed 's/version: //' | cut -d'+' -f1
}

# 获取构建号
get_build_number() {
    grep "^version:" "$PUBSPEC" | sed 's/version: //' | cut -d'+' -f2
}

# 解析版本号
parse_version() {
    local v="$1"
    echo "$v" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' > /dev/null
    if [ $? -ne 0 ]; then
        log_error "无效的版本号格式: $v (应为 x.x.x)"
        exit 1
    fi
}

# 更新 pubspec.yaml 版本号
update_version() {
    local new_version="$1"
    local build_number="$2"
    local old_line=$(grep "^version:" "$PUBSPEC")
    local new_line="version: ${new_version}+${build_number}"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^version:.*/version: ${new_version}+${build_number}/" "$PUBSPEC"
    else
        sed -i "s/^version:.*/version: ${new_version}+${build_number}/" "$PUBSPEC"
    fi
    
    log_info "版本号已更新: $old_line -> $new_line"
}

# 构建 APK
build_apk() {
    log_info "开始构建 APK..."
    cd "$SCRIPT_DIR"
    
    export JAVA_HOME="$HOME/Library/Java/JavaVirtualMachines/ms-17.0.18/Contents/Home"
    
    flutter clean > /dev/null 2>&1
    flutter pub get > /dev/null 2>&1
    flutter build apk --release 2>&1 | tail -5
    
    if [ ! -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        log_error "APK 构建失败"
        exit 1
    fi
    
    local apk_size=$(du -h "build/app/outputs/flutter-apk/app-release.apk" | cut -f1)
    log_info "APK 构建成功: $apk_size"
}

# Git 提交和打标签
git_release() {
    local version="$1"
    local tag="v${version}"
    
    cd "$SCRIPT_DIR"
    
    # 检查是否有未提交的更改
    if [ -n "$(git status --porcelain)" ]; then
        git add -A
        git commit -m "chore: release $tag"
        log_info "Git 提交完成"
    fi
    
    # 删除已存在的 tag（本地）
    git tag -d "$tag" 2>/dev/null || true
    
    # 创建新 tag
    git tag "$tag"
    log_info "Git 标签已创建: $tag"
    
    # 推送到 GitHub
    git push origin main --force
    git push origin "$tag" --force
    log_info "已推送到 GitHub"
}

# 创建 GitHub Release
create_github_release() {
    local version="$1"
    local tag="v${version}"
    local notes="$2"
    
    cd "$SCRIPT_DIR"
    
    # 删除已存在的 release
    gh release delete "$tag" --repo "$REPO" --yes 2>/dev/null || true
    
    # 创建新 release
    gh release create "$tag" \
        ./build/app/outputs/flutter-apk/app-release.apk \
        --repo "$REPO" \
        --title "$tag" \
        --notes "$notes"
    
    log_info "GitHub Release 已创建: https://github.com/$REPO/releases/tag/$tag"
}

# 上传到 COS
upload_to_cos() {
    local version="$1"
    
    log_info "上传 APK 到腾讯云 COS..."
    
    local TC_SCRIPT="$HOME/.openclaw/workspace/skills/tencent-cloud/scripts/tc"
    local APK_PATH="./build/app/outputs/flutter-apk/app-release.apk"
    
    # 上传到 COS（覆盖旧版本）
    $TC_SCRIPT cos upload claw-camp-1307257815 "$APK_PATH" releases/app-release.apk ap-guangzhou > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log_info "COS 上传成功: https://release.camp.aigc.sx.cn/releases/app-release.apk"
    else
        log_error "COS 上传失败"
        exit 1
    fi
}

# 更新服务器版本配置
update_server_config() {
    local version="$1"
    local notes="$2"
    
    log_info "更新服务器版本配置..."
    
    ssh -i "$SSH_KEY" "$SERVER_USER" "cat > ~/claw-hub/src/app-version.json << 'EOF'
{
  \"version\": \"$version\",
  \"downloadUrl\": \"https://release.camp.aigc.sx.cn/releases/app-release.apk\",
  \"releaseNotes\": \"$notes\"
}
EOF
cat ~/claw-hub/src/app-version.json"
    
    log_info "服务器配置已更新"
}

# 验证发布
verify_release() {
    local version="$1"
    
    log_info "验证发布..."
    
    # 检查 GitHub Release
    local release_info=$(gh release view "v${version}" --repo "$REPO" --json tagName,name 2>/dev/null)
    if [ -z "$release_info" ]; then
        log_error "GitHub Release 验证失败"
        exit 1
    fi
    
    # 检查服务器 API
    local server_version=$(curl -s https://camp.aigc.sx.cn/api/app/version | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    if [ "$server_version" != "$version" ]; then
        log_warn "服务器版本不匹配: $server_version != $version"
    else
        log_info "服务器版本验证通过: $version"
    fi
    
    log_info "✅ 发布成功！"
}

# 主流程
main() {
    local current_version=$(get_current_version)
    local current_build=$(get_build_number)
    
    log_info "当前版本: $current_version (build $current_build)"
    
    # 确定新版本号
    local new_version="$1"
    if [ -z "$new_version" ]; then
        # 自动递增补丁版本
        IFS='.' read -r major minor patch <<< "$current_version"
        new_version="$major.$minor.$((patch + 1))"
        log_info "自动递增版本: $current_version -> $new_version"
    else
        parse_version "$new_version"
    fi
    
    local new_build=$((current_build + 1))
    
    # 询问发布说明
    local notes="${2:-修复：时间戳本地化、消息状态实时更新}"
    if [ -z "$2" ]; then
        echo -n "请输入发布说明 (回车使用默认): "
        read -r input_notes
        [ -n "$input_notes" ] && notes="$input_notes"
    fi
    
    log_info "========== 开始发布 v${new_version} =========="
    log_info "发布说明: $notes"
    
    # 执行发布流程
    update_version "$new_version" "$new_build"
    build_apk
    upload_to_cos "$new_version"
    git_release "$new_version"
    create_github_release "$new_version" "$notes"
    update_server_config "$new_version" "$notes"
    verify_release "$new_version"
    
    log_info "========== 发布完成！ =========="
    log_info "下载地址: https://github.com/$REPO/releases/tag/v${new_version}"
}

# 运行
main "$@"
