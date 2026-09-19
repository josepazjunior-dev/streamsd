import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_item.dart';
import 'm3u_parser.dart';

class CatalogStore {
  static const requestHeaders = <String, String>{
    'User-Agent': 'Mozilla/5.0 (Android) StreamSD/1.2',
    'Accept': 'audio/x-mpegurl, application/vnd.apple.mpegurl, text/plain, */*',
    'Accept-Encoding': 'identity',
    'Connection': 'close',
  };
  final _prefs = SharedPreferencesAsync();
  Uri? sourceUri;
  List<MediaItem> items = [];
  Set<String> favorites = {};
  List<String> recent = [];

  Future<File> get _cache async =>
      File('${(await getApplicationDocumentsDirectory()).path}/playlist.m3u');

  Future<void> load() async {
    final savedUrl = await _prefs.getString('sourceUrl');
    sourceUri =
        savedUrl == null || savedUrl.isEmpty ? null : Uri.tryParse(savedUrl);
    favorites = (await _prefs.getStringList('favorites') ?? []).toSet();
    recent = await _prefs.getStringList('recent') ?? [];
    final file = await _cache;
    if (await file.exists()) {
      try {
        items =
            (await M3uParser.parseStream(file.openRead(), baseUri: sourceUri))
                .items;
      } catch (_) {
        items = [];
      }
    }
  }

  Future<int> importUrl(String value) async {
    final originalUri = Uri.tryParse(value.trim());
    if (originalUri == null ||
        !{'http', 'https'}.contains(originalUri.scheme) ||
        originalUri.host.isEmpty) {
      throw const FormatException('Informe uma URL http ou https válida.');
    }

    String lastError = 'falha de conexão';
    for (var attempt = 1; attempt <= 3; attempt++) {
      final client = http.Client();
      try {
        final result = await _openPlaylist(client, originalUri);
        return await _commit(
          result.response.stream.timeout(const Duration(minutes: 5)),
          originalUri,
        );
      } on http.ClientException catch (e) {
        lastError = e.message;
        if (attempt == 3) {
          throw const HttpException(
            'O servidor fechou a conexão antes de terminar a lista. Tente novamente em alguns instantes.',
          );
        }
      } on TimeoutException {
        lastError = 'tempo limite excedido';
        if (attempt == 3) {
          throw const HttpException(
            'O servidor demorou demais para responder. Tente novamente.',
          );
        }
      } on HandshakeException {
        throw const HttpException(
          'O servidor da lista respondeu com SSL/TLS incompatível. Tente novamente; o app já tentou corrigir redirecionamentos HTTPS incorretos.',
        );
      } on SocketException catch (e) {
        lastError = e.message;
        if (attempt == 3) {
          throw const HttpException(
            'Não foi possível manter conexão com o servidor da lista.',
          );
        }
      } finally {
        client.close();
      }

      await Future<void>.delayed(Duration(seconds: attempt));
    }

    throw HttpException('Falha ao importar a lista: $lastError');
  }

  Future<_PlaylistResponse> _openPlaylist(
      http.Client client, Uri originalUri) async {
    var current = originalUri;
    final visited = <String>{};

    for (var redirects = 0; redirects < 8; redirects++) {
      if (!visited.add(current.toString())) {
        throw const HttpException('O servidor entrou em um loop de redirecionamento.');
      }

      http.StreamedResponse response;
      try {
        response = await _sendWithoutRedirect(client, current);
      } on HandshakeException {
        // Alguns painéis Xtream redirecionam de http://host:porta para
        // https://host:mesma-porta, embora aquela porta aceite apenas HTTP.
        // Nesse caso o Android retorna WRONG_VERSION_NUMBER. Se isso acontecer,
        // voltamos para HTTP mantendo host, porta, caminho e parâmetros.
        if (current.scheme == 'https') {
          final fallback = current.replace(scheme: 'http');
          if (!visited.contains(fallback.toString())) {
            current = fallback;
            continue;
          }
        }
        rethrow;
      }

      if (response.statusCode == 200) {
        return _PlaylistResponse(response, current);
      }

      if (response.isRedirect) {
        final location = response.headers['location'];
        if (location == null || location.trim().isEmpty) {
          throw HttpException(
              'O servidor respondeu com redirecionamento sem destino.');
        }

        var next = current.resolve(location.trim());

        // Corrige o caso comum de painel que força HTTPS na mesma porta HTTP.
        if (current.scheme == 'http' &&
            next.scheme == 'https' &&
            next.host == current.host &&
            next.port == current.port) {
          next = next.replace(scheme: 'http');
        }

        current = next;
        continue;
      }

      throw HttpException(
          'A lista respondeu HTTP ${response.statusCode}.');
    }

    throw const HttpException('O servidor redirecionou a lista muitas vezes.');
  }

  Future<http.StreamedResponse> _sendWithoutRedirect(
      http.Client client, Uri uri) async {
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers.addAll(requestHeaders);
    return client.send(request).timeout(const Duration(minutes: 2));
  }

  Future<int?> importFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['m3u', 'm3u8', 'txt'],
    );
    if (file == null) return null;
    return _commit(file.readAsByteStream(), null);
  }

  Future<int> _commit(Stream<List<int>> source, Uri? uri) async {
    final saved = await _cache;
    final incoming = File('${saved.path}.incoming');

    if (await incoming.exists()) {
      await incoming.delete();
    }

    final sink = incoming.openWrite();
    var sinkClosed = false;

    try {
      await sink.addStream(source);
      await sink.flush();
      await sink.close();
      sinkClosed = true;

      final parser = await M3uParser.parseStream(
        incoming.openRead(),
        baseUri: uri,
      );

      if (!parser.sawEntry) {
        throw const FormatException('Arquivo sem entradas M3U EXTINF.');
      }
      if (parser.items.isEmpty) {
        throw const FormatException(
          'Nenhuma entrada SD identificada. Verifique os nomes e atributos da lista.',
        );
      }

      if (await saved.exists()) {
        await saved.delete();
      }
      await incoming.rename(saved.path);

      if (uri == null) {
        await _prefs.remove('sourceUrl');
      } else {
        await _prefs.setString('sourceUrl', uri.toString());
      }

      sourceUri = uri;
      items = parser.items;
      return items.length;
    } catch (_) {
      if (!sinkClosed) {
        try {
          await sink.close();
        } catch (_) {}
      }
      if (await incoming.exists()) {
        try {
          await incoming.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> toggleFavorite(MediaItem item) async {
    if (!favorites.add(item.id)) favorites.remove(item.id);
    await _prefs.setStringList('favorites', favorites.toList());
  }

  Future<void> markRecent(MediaItem item) async {
    recent.remove(item.id);
    recent.insert(0, item.id);
    if (recent.length > 30) recent = recent.sublist(0, 30);
    await _prefs.setStringList('recent', recent);
  }

  Future<void> clearCache() async {
    final file = await _cache;
    if (await file.exists()) await file.delete();
    await _prefs.remove('sourceUrl');
    await _prefs.remove('recent');
    sourceUri = null;
    items = [];
    recent = [];
  }
}

class _PlaylistResponse {
  const _PlaylistResponse(this.response, this.effectiveUri);

  final http.StreamedResponse response;
  final Uri effectiveUri;
}
