# Location Info Share Discord Bot

位置情報をDiscordに共有するシステム。ボタンクリックで現在地をDiscordチャンネルに送信。

## 構成

- **hono-location-info-share-discord-bot**: Hono API (Cloudflare Workers)
- **location-sharing-button**: React UI (Netlify)
- **flutter_location_publisher**: Flutterアプリ（Android対応）

## セットアップ

### バックエンド (Cloudflare Workers)

```bash
cd hono-location-info-share-discord-bot
npm install
cp .dev.vars.example .dev.vars
# .dev.varsにDISCORD_BOT_TOKEN, DISCORD_CHANNEL_IDを設定
npm run dev
```

### フロントエンド (Netlify)

```bash
cd location-sharing-button
npm install
npm run dev
```

### Flutterアプリ (Android)

```bash
cd flutter_location_publisher
flutter pub get
flutter run
```

## デプロイ

```bash
# バックエンド
wrangler secret put DISCORD_BOT_TOKEN
wrangler secret put DISCORD_CHANNEL_ID
npm run deploy

# フロントエンド
GitHubにプッシュするとNetlifyに自動デプロイ

# Flutterアプリ
flutter build apk
# 生成されたapkを配布
```

## API

- `POST /post`: 位置情報をDiscordに送信

## 技術スタック

- Hono + Cloudflare Workers
- React + Vite + Netlify
- Flutter
