import 'package:flutter/material.dart';
import 'models/media_item.dart';
import 'screens/player_screen.dart';
import 'services/catalog_store.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const StreamSdApp()); }

const accent = Color(0xFF19A7FF);
const accent2 = Color(0xFF635BFF);
const surface = Color(0xFF080B12);
const panel = Color(0xFF111722);
const panel2 = Color(0xFF171E2C);

class StreamSdApp extends StatelessWidget {
  const StreamSdApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'StreamSD', debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.dark(primary: accent, surface: surface),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        centerTitle: false,
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: panel,
        indicatorColor: Color(0x3328B8FF),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: const CardThemeData(color: panel),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: const HomeScreen(),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final catalog = CatalogStore();
  int tab = 0;
  bool busy = true;
  String? loadError;
  final kinds = MediaKind.values;

  @override
  void initState() { super.initState(); _init(); }
  Future<void> _init() async {
    try { await catalog.load(); }
    catch (_) { loadError = 'Não foi possível abrir o catálogo salvo.'; }
    if (mounted) setState(() => busy = false);
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _importUrl(String value) async {
    Navigator.pop(context);
    setState(() => busy = true);
    try { final count = await catalog.importUrl(value); _message('$count itens SD carregados.'); }
    catch (e) { _message('Não foi possível importar: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _importFile() async {
    Navigator.pop(context);
    setState(() => busy = true);
    try { final count = await catalog.importFile(); if (count != null) _message('$count itens SD carregados.'); }
    catch (e) { _message('Não foi possível importar: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  void _showImport() {
    final input = TextEditingController(text: catalog.sourceUri?.toString() ?? '');
    showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(22, 8, 22, MediaQuery.viewInsetsOf(sheetContext).bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Sua lista M3U', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Adicione uma lista de conteúdo que você tenha direito de acessar.'),
          const SizedBox(height: 18),
          TextField(controller: input, keyboardType: TextInputType.url, autocorrect: false,
            decoration: const InputDecoration(labelText: 'URL da lista M3U', hintText: 'https://…/lista.m3u', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: () => _importUrl(input.text), icon: const Icon(Icons.link), label: const Text('Carregar URL')),
          OutlinedButton.icon(onPressed: _importFile, icon: const Icon(Icons.folder_open), label: const Text('Selecionar arquivo M3U')),
          const SizedBox(height: 8),
          const Text('Na TV ao vivo, versões HD, FHD, 720p, 1080p, 4K e UHD são omitidas. Canais sem marcador de qualidade são tratados como SD.',
            style: TextStyle(fontSize: 12, color: Colors.white60)),
        ]),
      ),
    ).whenComplete(input.dispose);
  }

  void _open(MediaItem item) {
    catalog.markRecent(item).then((_) { if (mounted) setState(() {}); });
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PlayerScreen(item: item)));
  }

  void _search() {
    showSearch<MediaItem?>(context: context, delegate: _MediaSearch(catalog.items, _open));
  }

  Future<void> _confirmDeleteList(BuildContext settingsContext) async {
    if (catalog.items.isEmpty) {
      _message('Nenhuma lista carregada para excluir.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: settingsContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(children: [
          Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
          SizedBox(width: 10),
          Expanded(child: Text('Excluir lista atual?')),
        ]),
        content: const Text(
          'Tem certeza que deseja excluir a lista atual? Todos os canais, filmes, séries, favoritos e histórico desta lista serão removidos do aparelho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir lista'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await catalog.deleteCurrentList();
    if (!mounted) return;
    setState(() {
      tab = 0;
      loadError = null;
    });
    if (settingsContext.mounted) Navigator.pop(settingsContext);
    _message('Lista excluída do aparelho.');
  }

  void _settings() {
    Navigator.push(context, MaterialPageRoute<void>(builder: (settingsContext) => Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _settingsTile(
            icon: Icons.playlist_add_rounded,
            title: 'Adicionar ou atualizar lista',
            subtitle: 'Carregue um link M3U/Xtream ou um arquivo local.',
            onTap: () { Navigator.pop(settingsContext); _showImport(); },
          ),
          const SizedBox(height: 10),
          _settingsTile(
            icon: Icons.delete_forever_rounded,
            iconColor: Colors.redAccent,
            title: 'Excluir lista atual',
            subtitle: 'Remove completamente a lista, favoritos e histórico.',
            onTap: () => _confirmDeleteList(settingsContext),
          ),
          const SizedBox(height: 10),
          _settingsTile(
            icon: Icons.cleaning_services_outlined,
            title: 'Limpar cache e catálogo',
            subtitle: 'Remove a lista e o histórico; mantém favoritos.',
            onTap: () async {
              await catalog.clearCache();
              if (!mounted) return;
              setState(() {});
              if (settingsContext.mounted) Navigator.pop(settingsContext);
              _message('Catálogo local removido.');
            },
          ),
          const SizedBox(height: 10),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline_rounded, color: accent),
              title: Text('Sobre o StreamSD'),
              subtitle: Text('Catálogo M3U pessoal • canais SD • filmes e séries • reprodução no Android.'),
            ),
          ),
        ],
      ),
    )));
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: (iconColor ?? accent).withValues(alpha: .12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: iconColor ?? accent),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final items = catalog.items.where((e) => e.kind == kinds[tab]).toList();
    final groups = <String, List<MediaItem>>{};
    for (final item in items) { groups.putIfAbsent(item.group, () => []).add(item); }
    final featured = items.isEmpty ? null : items.first;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          _BrandMark(),
          SizedBox(width: 10),
          Text('Stream', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -.6)),
          Text('SD', style: TextStyle(color: accent, fontWeight: FontWeight.w900)),
        ]),
        actions: [
        IconButton(tooltip: 'Buscar', onPressed: _search, icon: const Icon(Icons.search)),
        IconButton(tooltip: 'Adicionar lista', onPressed: _showImport, icon: const Icon(Icons.playlist_add)),
        IconButton(tooltip: 'Configurações', onPressed: _settings, icon: const Icon(Icons.settings_outlined)),
      ]),
      body: busy ? const Center(child: CircularProgressIndicator())
        : loadError != null ? Center(child: Text(loadError!))
        : items.isEmpty ? _empty() : ListView(children: [
          if (featured != null) _hero(featured),
          _row('Minha lista', catalog.items.where((e) => catalog.favorites.contains(e.id)).toList()),
          _row('Assistidos recentemente', catalog.recent.map((id) {
            for (final item in catalog.items) { if (item.id == id) return item; } return null;
          }).whereType<MediaItem>().toList()),
          for (final entry in groups.entries) _row(entry.key.isEmpty ? 'Outros' : entry.key, entry.value),
          const SizedBox(height: 22),
        ]),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.live_tv_outlined), selectedIcon: Icon(Icons.live_tv), label: 'Canais'),
          NavigationDestination(icon: Icon(Icons.movie_outlined), selectedIcon: Icon(Icons.movie), label: 'Filmes'),
          NavigationDestination(icon: Icon(Icons.tv_outlined), selectedIcon: Icon(Icons.tv), label: 'Séries'),
        ]),
    );
  }

  Widget _empty() => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(
    mainAxisSize: MainAxisSize.min, children: [
      const _BrandMark(size: 82),
      const SizedBox(height: 24),
      Text(catalog.items.isEmpty ? 'Seu catálogo começa aqui' : 'Nenhum item nesta aba',
        style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      const SizedBox(height: 10),
      const Text('Importe uma lista M3U ou um link Xtream no formato get.php.', textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white60)),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: _showImport, icon: const Icon(Icons.add), label: const Text('Adicionar lista')),
    ],
  )));

  Widget _hero(MediaItem item) => Container(
    height: 220, margin: const EdgeInsets.fromLTRB(16, 12, 16, 14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        colors: [Color(0xFF0C5AA6), Color(0xFF25235F), Color(0xFF111722)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: Colors.white10),
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 18, offset: Offset(0, 8))],
    ),
    child: Stack(fit: StackFit.expand, children: [
      if (item.image.isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(item.image,
        fit: BoxFit.cover, errorBuilder: (context, error, stack) => const SizedBox.shrink())),
      DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(
        colors: [Colors.transparent, Color(0xE6000000)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
      Positioned(left: 20, right: 20, bottom: 18, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.group.toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 5), Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12), Align(alignment: Alignment.centerLeft,
          child: FilledButton.icon(onPressed: () => _open(item), icon: const Icon(Icons.play_arrow), label: const Text('Assistir'))),
      ])),
    ]),
  );

  Widget _row(String title, List<MediaItem> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 15, 16, 10), child: Text(title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20))),
      SizedBox(height: 190, child: ListView.builder(scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: entries.length,
        itemBuilder: (_, index) => _card(entries[index]))),
    ]);
  }

  Widget _card(MediaItem item) => SizedBox(width: 142, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Stack(children: [
        InkWell(onTap: () => _open(item), borderRadius: BorderRadius.circular(12),
          child: Container(width: double.infinity, decoration: BoxDecoration(
            color: panel2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
            clipBehavior: Clip.antiAlias,
            child: item.image.isNotEmpty ? Image.network(item.image, fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const Icon(Icons.play_circle_outline, size: 44, color: Colors.white54))
              : const Icon(Icons.play_circle_outline, size: 44, color: Colors.white54))),
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomRight: Radius.circular(10),
              ),
            ),
            child: Text(
              item.kind == MediaKind.channel ? 'SD' : (item.kind == MediaKind.movie ? 'FILME' : 'SÉRIE'),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .4),
            ),
          ),
        ),
        Positioned(top: 2, right: 2, child: IconButton.filledTonal(
          constraints: const BoxConstraints(minWidth: 34, minHeight: 34), padding: EdgeInsets.zero,
          tooltip: catalog.favorites.contains(item.id) ? 'Desfavoritar' : 'Favoritar',
          onPressed: () async { await catalog.toggleFavorite(item); if (mounted) setState(() {}); },
          icon: Icon(catalog.favorites.contains(item.id) ? Icons.favorite : Icons.favorite_border, size: 19,
            color: catalog.favorites.contains(item.id) ? accent : Colors.white))),
      ])),
      const SizedBox(height: 7), Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ])));
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [accent, accent2],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(size * .28),
      boxShadow: const [
        BoxShadow(color: Color(0x4428B8FF), blurRadius: 14, offset: Offset(0, 5)),
      ],
    ),
    child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: size * .62),
  );
}

class _MediaSearch extends SearchDelegate<MediaItem?> {
  _MediaSearch(this.items, this.onOpen);
  final List<MediaItem> items;
  final void Function(MediaItem) onOpen;
  @override String get searchFieldLabel => 'Buscar no catálogo';
  @override List<Widget> buildActions(BuildContext context) => [IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear))];
  @override Widget buildLeading(BuildContext context) => IconButton(onPressed: () => close(context, null), icon: const Icon(Icons.arrow_back));
  @override Widget buildResults(BuildContext context) => _results(context);
  @override Widget buildSuggestions(BuildContext context) => _results(context);
  Widget _results(BuildContext context) {
    final matches = items.where((e) => e.name.toLowerCase().contains(query.toLowerCase()) || e.group.toLowerCase().contains(query.toLowerCase())).take(100).toList();
    return ListView.builder(itemCount: matches.length, itemBuilder: (_, i) => ListTile(
      leading: const Icon(Icons.play_circle_outline), title: Text(matches[i].name), subtitle: Text(matches[i].group),
      onTap: () { final item = matches[i]; close(context, item); Future<void>.delayed(Duration.zero, () => onOpen(item)); },
    ));
  }
}
