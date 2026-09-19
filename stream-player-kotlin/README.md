# Stream Player Android

Player Android independente para listas M3U/M3U8 do próprio usuário, com identidade visual original inspirada em interfaces modernas de streaming.

## Recursos
- Home com TV ao Vivo, Filmes e Séries
- Importação por URL M3U/M3U8
- Importação por arquivo local via Storage Access Framework
- Parser de EXTINF, tvg-id, tvg-name, tvg-logo, tvg-chno e group-title
- Busca e categorias com LazyColumn/LazyRow
- Reprodução HLS/HTTP com AndroidX Media3/ExoPlayer
- Exclusão de listas com confirmação
- Cache local básico

## Build
Requer JDK 17 e Android SDK 35.

```bash
gradle :app:assembleDebug
```

APK: `app/build/outputs/apk/debug/app-debug.apk`

No GitHub, abra **Actions > Stream Player Android APK > Run workflow** e baixe o artifact **stream-player-debug-apk**.
