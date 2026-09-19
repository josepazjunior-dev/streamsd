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
    'User-Agent': 'Mozilla/5.0 (Android) StreamSD/1.1',
    'Accept': 'audio/x-mpegurl, application/vnd.apple.mpegurl, text/plain, */*',
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
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const FormatException('Informe uma URL http ou https válida.');
    }
    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      request.headers.addAll(requestHeaders);
      final response =
          await client.send(request).timeout(const Duration(minutes: 2));
      if (response.statusCode != 200) {
        throw HttpException(
            'A lista respondeu HTTP ${response.statusCode}.');
      }
      return _commit(
        response.stream.timeout(const Duration(minutes: 2)),
        uri,
      );
    } on TimeoutException {
      throw const HttpException(
          'O servidor demorou demais para responder. Tente novamente.');
    } on SocketException {
      throw const HttpException(
          'Não foi possível conectar ao servidor da lista.');
    } finally {
      client.close();
    }
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
      // Grava em fluxo para suportar listas grandes sem carregar o arquivo
      // inteiro na memória.
      await sink.addStream(source);
      await sink.flush();
      await sink.close();
      sinkClosed = true;

      // Só começa a leitura depois que a gravação foi encerrada de verdade.
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

      // No Android, substituir explicitamente o cache evita falha de rename
      // quando já existe uma playlist anterior.
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
        } catch (_) {
          // Evita mascarar o erro original com "File closed".
        }
      }
      if (await incoming.exists()) {
        try {
          await incoming.delete();
        } catch (_) {
          // A limpeza é secundária; preserva o erro real da importação.
        }
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
