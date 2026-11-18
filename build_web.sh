#!/bin/bash
# 匯出網頁版到 docs/（GitHub Pages 從這裡架站）。
# 每次匯出用新的檔名（game_<版本>.js/.wasm/.pck），瀏覽器就不會拿到快取的舊檔案。
# index.html 會指向最新版；保留上一版的檔案，讓還開著舊 index.html 的人不會壞掉。
set -euo pipefail
cd "$(dirname "$0")"

VER="$(date +%Y%m%d-%H%M%S)"
SHOW="v$(date +%Y.%m.%d-%H%M)"

# 版本號寫進遊戲裡，選角畫面右下角會顯示
printf '## 由 build_web.sh 自動產生，不要手改\nconst TEXT := "%s"\n' "$SHOW" > version.gd

godot --headless --export-release "Web" "docs/game_${VER}.html"
mv "docs/game_${VER}.html" docs/index.html
rm -f docs/index.js docs/index.wasm docs/index.pck docs/index.png docs/index.icon.png \
	docs/index.apple-touch-icon.png docs/index.audio.worklet.js docs/index.audio.position.worklet.js

# 只留最新的兩版
ls docs/game_*.pck | sort -r | tail -n +3 | while read -r old; do
	base="${old%.pck}"
	rm -f "${base}".*
done

echo "匯出完成：${SHOW}（docs/game_${VER}.*）"
