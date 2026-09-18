# StreamSD

Aplicativo Flutter para Android que abre listas M3U próprias, guarda o catálogo no aparelho e apresenta **somente entradas identificadas como SD**. Interface escura com canais, filmes, séries, busca, favoritos, histórico e player em tela cheia.

## Como gerar o APK (Windows, macOS ou Linux)

1. Instale [Flutter](https://docs.flutter.dev/get-started/install) e o Android SDK (Android Studio). Rode `flutter doctor` e conclua as pendências de Android.
2. Descompacte o ZIP, abra um terminal dentro da pasta `streamsd` e execute:

   ```bash
   flutter create --platforms=android --org com.example .
   flutter pub get
   flutter test test/m3u_parser_test.dart
   flutter build apk --release
   ```

3. O arquivo ficará em `build/app/outputs/flutter-apk/app-release.apk`. Envie esse arquivo ao celular e instale. Pode ser necessário permitir a instalação de aplicativos da fonte usada para abrir o APK.

## Gerar pelo GitHub, sem instalar Flutter no computador

1. Crie um repositório no GitHub e envie **os arquivos do projeto**, inclusive `.github/workflows/android-apk.yml` (não apenas o ZIP). A pasta `.github` pode ficar oculta no explorador de arquivos, mas precisa ir junto.
2. Abra o repositório > **Actions** > **Gerar APK Android**. O primeiro envio à branch `main` inicia a compilação. Para repetir, clique **Run workflow** > **Run workflow**.
3. Aguarde a execução ficar verde, abra a execução e clique em **StreamSD-Android-APK** na seção **Artifacts**. O GitHub baixa um ZIP; descompacte-o para obter `app-release.apk`.

O APK é gerado para **teste e instalação manual**. A assinatura padrão criada pelo projeto Flutter não serve como plano de publicação com identidade estável na Play Store; para publicar, configure sua chave de assinatura privada sem enviá-la ao repositório. O fluxo mantém o APK por 30 dias e precisa de GitHub Actions habilitado. Se a execução falhar, abra o passo vermelho e consulte os logs antes de usar o APK.

`flutter create` completa os arquivos de plataforma e o wrapper Gradle específicos da versão instalada do Flutter. Os arquivos `android/app/src/main/AndroidManifest.xml` e `MainActivity.kt` deste projeto definem o rótulo, acesso à rede, HTTP para streams legados e a atividade inicial. **Após `flutter create`, confira se o Manifest continua com `INTERNET` e `usesCleartextTraffic="true"`; se for sobrescrito, restaure o arquivo do ZIP.** Não há necessidade de inserir senhas de listas no código.

## Usar

Na tela inicial, toque em adicionar lista, cole uma URL `http(s)` ou selecione um arquivo `.m3u`, `.m3u8` ou `.txt`. A lista original é copiada para a área privada do aplicativo para abrir o catálogo sem internet. Atualizar uma URL exige importar novamente. Canais, filmes e episódios são classificados a partir do texto `group-title` (grupo com “filmes/movies/vod” vira Filmes; grupo com “séries/series/temporada/episódio/tv shows” vira Séries; os demais viram Canais). Formatos cujo grupo não seguir essa convenção podem aparecer em Canais.

## Limites do filtro SD

- Só entram itens cujo **nome, grupo ou atributos** declarem `SD`, `480p` ou `576p`. Entradas sem indicação são descartadas.
- Se nome, grupo ou atributos também contiverem `HD`, `FHD`, `Full HD`, `HDTV`, `720`, `1080`, `1440`, `2160`, `4K`, `8K` ou `UHD`, o item é descartado. Uma entrada SD duplicada é mostrada uma vez por nome/grupo/tipo.
- M3U não comprova resolução real. Se o servidor rotular um vídeo HD como SD, o aplicativo não consegue detectá-lo. Uma URL HLS com variantes adaptativas também pode alternar de qualidade; esta versão não reescreve manifestos para travar a variante SD.
- O player usa o pacote `video_player`, que no Android usa ExoPlayer. A reprodução depende dos formatos e da disponibilidade do servidor; não há suporte a DRM, EPG, login do provedor nem cabeçalhos personalizados.
- A interface e o catálogo funcionam offline; reprodução, atualização e imagens remotas dependem de conexão. A opção “limpar catálogo local” apaga a lista copiada e o histórico, mantendo favoritos. A importação é feita em partes, sem limite fixo de 30 MB; listas muito grandes dependem do espaço livre e da memória disponível no aparelho para exibir os itens filtrados.

Use somente streams e listas aos quais você tenha acesso autorizado. URLs com tokens e o conteúdo M3U permanecem no armazenamento privado do aplicativo, sem criptografia adicional; evite compartilhar backups do aplicativo.
