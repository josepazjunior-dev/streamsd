enum MediaKind { channel, movie, series }

class MediaItem {
  const MediaItem({required this.name, required this.group, required this.url,
    required this.kind, this.image = ''});

  final String name;
  final String group;
  final String url;
  final String image;
  final MediaKind kind;

  // Chave independente de tokens temporários que possam mudar na URL.
  String get id => '${kind.name}|${group.toLowerCase()}|${name.toLowerCase()}';
}
