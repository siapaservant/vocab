# 單字卡片盒 — 給 Claude（含排程）的規則

網站：https://siapaservant.github.io/vocab/ （GitHub Pages，main 分支根目錄，push 後約 1 分鐘上線）
語言：回報一律用中文。

## 檔案
- `index.html`：整個 app。重要區塊：
  - `/* ===== WORD-SHARDS START ... END */`：`const SHARDS=[...]`，新增單字檔要把檔名加進去。
  - `/* ===== DAILY-SENTENCE START ... END */`：每日一句（只有每日任務能改）。
  - `/* NEWS START ... NEWS END */`：今天的新聞（只有每日任務能改）。
- `words/bNNN.json`：單字檔，格式 `{"分類":[[word, ipa, pos, zh, 例句, 例句中文, 型態變化]], "COLLOC":{...}}`，每筆 7 欄。
- `words/news-archive.json`：前 4 天新聞；`words/news-gloss.json`：新聞點字小字典；`words/confuse.json`：易混字題庫。
- `words/ceec-levels.json`、`words/toefl-ref.json`：挑字用參考清單，不要算進「已存在單字」。
- `supabase/setup.sql`：雲端帳號資料庫設定（使用者在 Supabase SQL Editor 執行）。

## 一定要遵守
- 不要改 localStorage 的 `KEY`（vocab-box-family-v2）、使用者資料欄位，也不要改 SB_URL / SB_KEY 或雲端帳號相關程式（acct*/cloud*/rpc/renderLogin）。
- 不要刪除既有功能。
- 單字不能重複（不分大小寫，B + 所有 SHARDS 檔一起算），用程式檢查。
- 改完先用 node 檢查 `<script>` 沒有語法錯誤再 commit。
- 工作流程：`git pull --rebase origin main` → 修改 → commit → `git push origin main`。push 被拒就再 pull --rebase 後重推，不要 force push。
- commit 訊息用中文寫清楚改了什麼。
