---
title: "Claude × Obsidian MCP 連携 障害対応記録（VPS/HTTPS/OAuth）"
date: 2026-01-29
tags: [mcp, obsidian, claude, vps, nginx, oauth, troubleshooting]
aliases: ["MCP連携 障害対応記録 2026-01-28"]
---

## 概要
iPhone/Claude から Obsidian Vault を操作するために、VPS 上で `obsidian-mcp` を HTTPS（nginx リバプロ） + OAuth で公開し、Claude 側に MCP Server として登録した。  
登録時にエラーが発生したが、**`/mcp` の GET 応答が誤解を招く固定メッセージ**になっていたことが主因で、ルートの挙動を修正して解消。最終的に **Claude 側で `initialize` → `tools/list` まで成功**し、連携完了。

> [!success] 結果
> Claude 側から MCP 接続が確立し、ツール一覧取得まで成功（= 実運用フェーズへ移行）。

---

## 環境
- VPS: Ubuntu（nginx 1.24.0）
- MCP 実装: `obsidian-mcp`（Node/Express）
- 公開: `https://mcp.gekidanfax.com`（nginx → localhost:3000）
- MCP Endpoint: `POST /mcp`
- Health: `GET /health`
- OAuth Discovery: `/.well-known/oauth-authorization-server`

> [!warning] セキュリティ
> このスレッド中にトークン類が一時的に露出したため、**PAT / PERSONAL_AUTH_TOKEN / Client Secret は再生成してローテーション済み**（記録では値は記載しない）。

---

## 症状
Claude に MCP Server を登録しようとすると接続エラー。サーバ側ログでは OAuth フローは進んでいるが、MCP 呼び出し側で 404/405 が混在。

- OAuth のリクエストは到達（`/oauth/authorize`, `/oauth/token`）
- その後 `POST /` が 404 になっているログが見えた（当時）
- `/mcp` にアクセスすると 405 だが、本文が **`SSE streaming is not supported in Lambda`** と出て混乱

---

## 事実確認（切り分け）

### 1) DNS/HTTPS 到達性
```bash
nslookup mcp.gekidanfax.com
curl https://mcp.gekidanfax.com/health
```
- `health` が `{"status":"ok","oauth":"enabled","vault":"configured"}` を返し、外部到達はOK。

### 2) OAuth Discovery
```bash
curl -i https://mcp.gekidanfax.com/.well-known/oauth-authorization-server
```
- 200 OK（issuer/authorization_endpoint/token_endpoint などが返る）

### 3) MCP 入口の確認
```bash
curl -i https://mcp.gekidanfax.com/
curl -i https://mcp.gekidanfax.com/mcp
```
- `/` は 404（想定どおり）
- `/mcp` は 405（ただし本文が「Lambda云々」）

> [!note] 重要
> `MCP endpoint は /mcp`。ルート `/` ではないため、Claude 側登録URLも `/mcp` が正。

---

## 混乱点の解体：「Lambdaメッセージ」の正体
当初、`/mcp` の 405 本文に
`SSE streaming is not supported in Lambda`
が出続けたため、Lambda モード判定の誤作動を疑った。

しかしソース検索で判明したのは、**GET /mcp に対して固定でこの文言を返すコードが存在**していたこと。  
実際の MCP 実処理は `POST /mcp` にあり、OAuth/Bearer 認証付きで稼働していた。

### 該当箇所（編集前）
ファイル: `packages/app/src/server/shared/mcp-routes.ts`

```ts
app.get('/mcp', (_req, res) => {
  res.status(405).json({
    error: 'method_not_allowed',
    error_description: 'SSE streaming is not supported in Lambda',
  });
});
```

> [!tip] 影響
> Claude が接続チェックで **GET /mcp** を叩く場合、この固定文言が「このサーバは無理」と解釈されやすく、登録失敗の原因になりうる。

---

## 対応（修正内容）
### 1) GET /mcp の応答を「説明的な 200」に変更
Claude の接続チェックに優しく、誤解を生まない応答に変更。

#### 編集後
```ts
app.get('/mcp', (_req, res) => {
  res.status(200).json({
    status: 'ok',
    message: 'MCP endpoint is POST /mcp',
    auth: 'Bearer token required',
  });
});
```

### 2) 反映確認
VPS内/外部どちらからも同じ応答が返ることを確認。

```bash
curl -i http://127.0.0.1:3000/mcp
curl -i https://mcp.gekidanfax.com/mcp
```

期待値:
- `HTTP/1.1 200 OK`
- JSON: `MCP endpoint is POST /mcp`

---

## 追加の重要確認：Bearer なし POST は 401 で正しい
MCP の本処理は `POST /mcp` で、OAuth で得たアクセストークンを Bearer として付与して叩く設計。  
そのため、Bearer なし POST は拒否されるのが正しい。

```bash
curl -i -X POST https://mcp.gekidanfax.com/mcp   -H "content-type: application/json"   -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
```

結果（想定どおり）:
- `401 Unauthorized`
- `Missing or invalid Authorization header`

> [!note] 意味
> クライアント（Claude）が OAuth を完了して Bearer を付ければ、この 401 は発生しない。

---

## 最終結果（成功ログ）
Claude 側で OAuth が通り、MCP 初期化とツール一覧取得まで完了。

```json
{"message":"Session authenticated successfully", ...}
{"message":"MCP request completed","context":{"method":"initialize","success":true}}
{"message":"MCP request completed","context":{"method":"notifications/initialized","success":true}}
{"message":"MCP request completed","context":{"method":"tools/list","success":true}}
```

> [!success] 成功判定
> `initialize` と `tools/list` が success=true なら、Claude が MCP を認識して実利用できる状態。

---

## 学び（次回の自分へ）
1. **入口URLは `/mcp`**  
   `/` は 404 でも正常。Claude登録も `/mcp` を指定する。
2. **GET /mcp の返し方で接続チェックが落ちうる**  
   “Lambda云々”など誤解される文言は避け、200 + 案内にする。
3. **OAuth discovery と health は最強の切り分けポイント**  
   `/.well-known/oauth-authorization-server` と `/health` が通るなら、TLS/リバプロ/DNS はほぼOK。
4. **Bearer なし POST の 401 は正常**  
   クライアントが OAuth を完了できているかはサーバログで `Session authenticated successfully` を見る。
5. **トークンは記録に残さない**  
   ログやメモに貼ったら“漏れた扱い”で即ローテする。

---

## チェックリスト（運用）
- [ ] pm2/systemd などで常駐化（SSH切断で落ちない）
- [ ] nginx の SSE 安定化設定（必要なら `proxy_buffering off` など）
- [ ] トークンの保管は Obsidian 内でも秘匿（`.env` はGit管理しない）
- [ ] Vault 同期（Obsidian Git / Auto pull/push）

---

## 関連
- ガイド: iOS Claude × Obsidian連携（Git-backed MCP / HTTPS）
- エンドポイント:
  - Health: `/health`
  - OAuth Discovery: `/.well-known/oauth-authorization-server`
  - MCP: `POST /mcp`
