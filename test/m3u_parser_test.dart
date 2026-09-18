import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamsd/models/media_item.dart';
import 'package:streamsd/services/m3u_parser.dart';

void main() {
  test('seleciona só SD, limpa nome, elimina duplicatas e conserva episódios', () {
    const list = '''#EXTM3U
#EXTINF:-1 tvg-logo="https://example.com/a.png" group-title="Esportes",Arena [SD]
https://example.com/a.m3u8
#EXTINF:-1 group-title="Esportes",Arena [HD]
https://example.com/b.m3u8
#EXTINF:-1 group-title="Esportes",Arena SD
https://example.com/c.m3u8
#EXTINF:-1 group-title="Notícias",Informativo
https://example.com/d.m3u8
#EXTINF:-1 group-title="Filmes",Meu filme 480p
https://example.com/e.mp4
#EXTINF:-1 group-title="Séries",Drama S01E01 SD
https://example.com/ep1.mp4
#EXTINF:-1 group-title="Séries",Drama S01E02 SD
https://example.com/ep2.mp4
''';
    final result = M3uParser.parse(list);
    expect(result.length, 4);
    expect(result.first.name, 'Arena');
    expect(result.first.image, 'https://example.com/a.png');
    expect(result[1].kind, MediaKind.movie);
    expect(result[2].kind, MediaKind.series);
    expect(result[3].name, 'Drama S01E02');
  });

  test('não aprova entrada com SD e variante HD simultaneamente', () {
    final result = M3uParser.parse('''#EXTM3U
#EXTINF:-1 group-title="TV SD" tvg-name="Canal FHD",Canal SD
https://example.com/hd.m3u8
#EXTINF:-1 group-title="TV SD",Outro SD
https://example.com/sd.m3u8
''');
    expect(result.map((e) => e.name).toList(), ['Outro']);
  });

  test('ignora vírgula entre aspas e resolve caminhos relativos', () {
    final result = M3uParser.parse('''#EXTM3U
#EXTINF:-1 group-title="News, World",Canal 576p
stream.m3u8
''', baseUri: Uri.parse('https://example.com/lists/main.m3u'));
    expect(result.single.group, 'News, World');
    expect(result.single.url, 'https://example.com/lists/stream.m3u8');
  });

  test('processa fluxo acima de 30 MB em partes sem rejeitar a entrada SD', () async {
    final filler = utf8.encode('#${'x' * 65534}\n');
    final parts = List<List<int>>.filled(512, filler, growable: true);
    parts.add(utf8.encode('#EXTINF:-1 group-title="Canais",Teste SD\nhttps://example.com/sd.m3u8\n'));
    final parser = await M3uParser.parseStream(Stream<List<int>>.fromIterable(parts));
    expect(parser.items.single.name, 'Teste');
  });
}
