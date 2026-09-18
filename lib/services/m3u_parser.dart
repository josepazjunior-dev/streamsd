import '../models/media_item.dart';

class M3uParser {
  static final _higher = RegExp(
    r'(?<![a-z0-9])(?:full[\s._-]*hd|fhd|hdtv|hd|uhd|4[\s._-]*k|8[\s._-]*k|(?:720|1080|1440|2160|4320)[pi]?)(?![a-z0-9])',
    caseSensitive: false,
  );
  static final _sd = RegExp(r'(?<![a-z0-9])(?:sd|480[pi]?|576[pi]?)(?![a-z0-9])', caseSensitive: false);
  static final _clean = RegExp(r'(?<![a-z0-9])(?:sd|480[pi]?|576[pi]?)(?![a-z0-9])', caseSensitive: false);
  static final _attributes = RegExp(r'([\w-]+)\s*=\s*"([^"]*)"');

  /// Conservador: qualidade desconhecida é descartada. Não verifica o bitrate
  /// real e não força uma variante SD dentro de um manifesto HLS adaptativo.
  static List<MediaItem> parse(String raw, {Uri? baseUri}) {
    final result = <MediaItem>[];
    final seen = <String>{};
    String? extinf;
    for (final original in raw.split(RegExp(r'\r?\n'))) {
      final line = original.trim();
      if (line.startsWith('#EXTINF:')) {
        extinf = line;
        continue;
      }
      if (line.isEmpty || line.startsWith('#')) continue;
      if (extinf == null) continue;
      final metadata = extinf;
      extinf = null;
      final attrs = <String, String>{};
      for (final match in _attributes.allMatches(metadata)) {
        attrs[match.group(1)!.toLowerCase()] = match.group(2)!.trim();
      }
      final namePart = _afterMetadataComma(metadata).trim();
      final rawName = namePart.isEmpty ? (attrs['tvg-name'] ?? '') : namePart;
      final group = attrs['group-title'] ?? 'Outros';
      // Usa metadados textuais, mas ignora a URL do logo: o nome do arquivo
      // de imagem não informa a qualidade do vídeo.
      final labels = '$rawName ${attrs.entries.where((e) => e.key != 'tvg-logo').map((e) => e.value).join(' ')}';
      if (_higher.hasMatch(labels) || !_sd.hasMatch(labels)) continue;
      final cleanName = rawName.replaceAll(_clean, '').replaceAll(RegExp(r'\s*[\[\](){}|]+\s*'), ' ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
      if (cleanName.isEmpty) continue;
      final resolved = baseUri?.resolve(line) ?? Uri.tryParse(line);
      if (resolved == null || !{'http', 'https'}.contains(resolved.scheme)) continue;
      final groupLower = group.toLowerCase();
      final kind = RegExp(r's[ée]ries|series|temporada|epis[oó]dio|tv shows').hasMatch(groupLower)
          ? MediaKind.series
          : RegExp(r'filmes|movies|cinema|vod').hasMatch(groupLower)
              ? MediaKind.movie : MediaKind.channel;
      final item = MediaItem(name: cleanName, group: group.replaceAll(_clean, '').trim(),
        url: resolved.toString(), image: attrs['tvg-logo'] ?? '', kind: kind);
      if (seen.add(item.id)) result.add(item);
    }
    return result;
  }

  // Vírgulas dentro de atributos entre aspas não dividem o título.
  static String _afterMetadataComma(String line) {
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      if (line[i] == '"') quoted = !quoted;
      if (line[i] == ',' && !quoted) return line.substring(i + 1);
    }
    return '';
  }
}
