import 'package:flutter/material.dart';
import 'models/media_item.dart';
import 'screens/player_screen.dart';
import 'services/catalog_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StreamSdApp());
}

const accent = Color(0xFF159DFF);
const accent2 = Color(0xFF8B35F5);
const surface = Color(0xFF050911);
const panel = Color(0xFF0F1622);
const panel2 = Color(0xFF151D2B);
const outline = Color(0xFF293246);

class StreamSdApp extends StatelessWidget {
  const StreamSdApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'StreamSD',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: surface,
          colorScheme: const ColorScheme.dark(
            primary: accent,
            secondary: accent2,
            surface: surface,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: surface,
            elevation: 0,
            centerTitle: false,
          ),
          navigationBarTheme: const NavigationBarThemeData(
            backgroundColor: panel,
            indicatorColor: Color(0x338B35F5),
            labelTextStyle: WidgetStatePropertyAll(
              TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          cardTheme: const CardThemeData(
            color: panel,
            elevation: 0,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: panel2,
            hintStyle: const TextStyle(color: Colors.white38),
            labelStyle: const TextStyle(color: Colors.white70),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: accent, width: 1.4),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
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
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await catalog.load();
    } catch (_) {
      loadError = 'Não foi possível abrir o catálogo salvo.';
    }
    if (mounted) setState(() => busy = false);
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: panel2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(text),
      ),
    );
  }

  Future<void> _importUrl(String value) async {
    Navigator.pop(context);
    setState(() => busy = true);
    try {
      final count = await catalog.importUrl(value);
      _message('$count itens SD carregados.');
    } catch (e) {
      _message('Não foi possível importar: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _importFile() async {
    Navigator.pop(context);
    setState(() => busy = true);
    try {
      final count = await catalog.importFile();
      if (count != null) _message('$count itens SD carregados.');
    } catch (e) {
      _message('Não foi possível importar: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _showImport() {
    final input =
        TextEditingController(text: catalog.sourceUri?.toString() ?? '');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: panel,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                _BrandMark(size: 42),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Adicionar lista',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Importe sua lista M3U/M3U8 ou um link Xtream.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: input,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.link_rounded),
                labelText: 'URL da lista',
                hintText: 'https://seusite.com/lista.m3u8',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [accent, accent2]),
                borderRadius: BorderRadius.circular(15),
              ),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                onPressed: () => _importUrl(input.text),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Importar'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _importFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Selecionar arquivo M3U'),
            ),
            const SizedBox(height: 12),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 17, color: Colors.white54),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Na TV ao vivo, HD, FHD, 720p, 1080p, 4K e UHD continuam sendo omitidos. Canais sem marcador de qualidade são tratados como SD.',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).whenComplete(input.dispose);
  }

  void _open(MediaItem item) {
    catalog.markRecent(item).then((_) {
      if (mounted) setState(() {});
    });
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => PlayerScreen(item: item)),
    );
  }

  void _search() {
    showSearch<MediaItem?>(
      context: context,
      delegate: _MediaSearch(catalog.items, _open),
    );
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
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Expanded(child: Text('Excluir lista atual?')),
          ],
        ),
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
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (settingsContext) => Scaffold(
          appBar: AppBar(
            titleSpacing: 18,
            title: const Text(
              'Configurações',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 18),
                child: Icon(Icons.verified_user_outlined, color: accent2),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              const _SettingsBrand(),
              const SizedBox(height: 18),
              _settingsGroup(
                title: 'Listas',
                icon: Icons.format_list_bulleted_rounded,
                child: Column(
                  children: [
                    _settingsAction(
                      icon: Icons.add_link_rounded,
                      title: 'Adicionar ou atualizar lista',
                      subtitle: 'M3U, M3U8, Xtream ou arquivo local.',
                      onTap: () {
                        Navigator.pop(settingsContext);
                        _showImport();
                      },
                    ),
                    const Divider(height: 1, indent: 64),
                    _settingsAction(
                      icon: Icons.delete_forever_rounded,
                      iconColor: Colors.redAccent,
                      title: 'Excluir lista atual',
                      subtitle: 'Remove completamente a lista deste aparelho.',
                      onTap: () => _confirmDeleteList(settingsContext),
                    ),
                    const Divider(height: 1, indent: 64),
                    _settingsAction(
                      icon: Icons.cleaning_services_outlined,
                      title: 'Limpar cache e catálogo',
                      subtitle: 'Remove a lista e o histórico; mantém favoritos.',
                      onTap: () async {
                        await catalog.clearCache();
                        if (!mounted) return;
                        setState(() {});
                        if (settingsContext.mounted) {
                          Navigator.pop(settingsContext);
                        }
                        _message('Catálogo local removido.');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _settingsGroup(
                title: 'Sobre',
                icon: Icons.info_outline_rounded,
                child: const ListTile(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: _BrandMark(size: 42),
                  title: Text(
                    'StreamSD',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    'Catálogo M3U pessoal • canais SD • filmes e séries • reprodução no Android.',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 16, color: Colors.white38),
                    SizedBox(width: 7),
                    Text(
                      'Seus dados ficam armazenados no aparelho.',
                      style: TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsGroup({
    required String title,
    required IconData icon,
    required Widget child,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0x33249FFF), Color(0x448B35F5)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent2, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            child,
          ],
        ),
      );

  Widget _settingsAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) =>
      ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: (iconColor ?? accent).withValues(alpha: .12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: iconColor ?? accent),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );

  @override
  Widget build(BuildContext context) {
    final items = catalog.items.where((e) => e.kind == kinds[tab]).toList();
    final groups = <String, List<MediaItem>>{};
    for (final item in items) {
      groups.putIfAbsent(item.group, () => []).add(item);
    }
    final featured = items.isEmpty ? null : items.first;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 74,
        titleSpacing: 16,
        title: const _WordMark(),
        actions: [
          _roundIcon(Icons.search_rounded, _search, 'Buscar'),
          const SizedBox(width: 6),
          _roundIcon(Icons.playlist_add_rounded, _showImport, 'Adicionar lista'),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _roundIcon(
              Icons.settings_outlined,
              _settings,
              'Configurações',
            ),
          ),
        ],
      ),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
              ? Center(child: Text(loadError!))
              : catalog.items.isEmpty
                  ? _empty()
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: _topTabs()),
                        if (featured != null && tab != 0)
                          SliverToBoxAdapter(child: _hero(featured)),
                        if (catalog.favorites.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _row(
                              'Minha lista',
                              catalog.items
                                  .where((e) =>
                                      catalog.favorites.contains(e.id))
                                  .toList(),
                            ),
                          ),
                        if (catalog.recent.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _row(
                              'Assistidos recentemente',
                              catalog.recent
                                  .map((id) {
                                    for (final item in catalog.items) {
                                      if (item.id == id) return item;
                                    }
                                    return null;
                                  })
                                  .whereType<MediaItem>()
                                  .toList(),
                            ),
                          ),
                        for (final entry in groups.entries)
                          SliverToBoxAdapter(
                            child: tab == 0
                                ? _liveSection(
                                    entry.key.isEmpty ? 'Outros' : entry.key,
                                    entry.value,
                                  )
                                : _row(
                                    entry.key.isEmpty ? 'Outros' : entry.key,
                                    entry.value,
                                  ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 28)),
                      ],
                    ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: outline)),
        ),
        child: NavigationBar(
          height: 72,
          selectedIndex: tab,
          onDestinationSelected: (index) => setState(() => tab = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.live_tv_outlined),
              selectedIcon: Icon(Icons.live_tv_rounded),
              label: 'Canais',
            ),
            NavigationDestination(
              icon: Icon(Icons.movie_outlined),
              selectedIcon: Icon(Icons.movie_rounded),
              label: 'Filmes',
            ),
            NavigationDestination(
              icon: Icon(Icons.tv_outlined),
              selectedIcon: Icon(Icons.tv_rounded),
              label: 'Séries',
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundIcon(IconData icon, VoidCallback onTap, String tooltip) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: panel,
          side: const BorderSide(color: outline),
        ),
        icon: Icon(icon),
      );

  Widget _topTabs() => SizedBox(
        height: 58,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
          scrollDirection: Axis.horizontal,
          children: [
            _pill(0, Icons.wifi_tethering_rounded, 'Canais'),
            _pill(1, Icons.movie_rounded, 'Filmes'),
            _pill(2, Icons.tv_rounded, 'Séries'),
          ],
        ),
      );

  Widget _pill(int index, IconData icon, String label) {
    final selected = tab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => setState(() => tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [accent, accent2])
                : null,
            color: selected ? null : panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? Colors.transparent : outline,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  color: selected ? Colors.white : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _BrandMark(size: 86),
              const SizedBox(height: 24),
              const _WordMark(large: true),
              const SizedBox(height: 12),
              const Text(
                'Seu catálogo começa aqui',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Importe uma lista M3U ou um link Xtream no formato get.php.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 330),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [accent, accent2]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  onPressed: _showImport,
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text('Adicionar lista'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _hero(MediaItem item) => Container(
        height: 250,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [Color(0xFF102F58), Color(0xFF28174F), panel],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: outline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33159DFF),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.image.isNotEmpty)
              Image.network(
                item.image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0xF2050911)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.kind == MediaKind.movie
                        ? 'DESTAQUE • FILME'
                        : 'DESTAQUE • SÉRIE',
                    style: const TextStyle(
                      color: accent2,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 27,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient:
                              const LinearGradient(colors: [accent, accent2]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          onPressed: () => _open(item),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Assistir'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: catalog.favorites.contains(item.id)
                            ? 'Desfavoritar'
                            : 'Favoritar',
                        onPressed: () async {
                          await catalog.toggleFavorite(item);
                          if (mounted) setState(() {});
                        },
                        icon: Icon(
                          catalog.favorites.contains(item.id)
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: catalog.favorites.contains(item.id)
                              ? accent2
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _sectionHeader(String title, {String? trailing}) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: const TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      );

  Widget _liveSection(String title, List<MediaItem> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title),
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: entries.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.28,
          ),
          itemBuilder: (_, index) => _liveCard(entries[index]),
        ),
      ],
    );
  }

  Widget _liveCard(MediaItem item) => InkWell(
        onTap: () => _open(item),
        borderRadius: BorderRadius.circular(17),
        child: Container(
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: item.image.isNotEmpty
                    ? Image.network(
                        item.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _PosterFallback(),
                      )
                    : const _PosterFallback(),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Color(0xE6050911)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 9,
                left: 9,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6213A),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Text(
                    'AO VIVO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  tooltip: catalog.favorites.contains(item.id)
                      ? 'Desfavoritar'
                      : 'Favoritar',
                  onPressed: () async {
                    await catalog.toggleFavorite(item);
                    if (mounted) setState(() {});
                  },
                  icon: Icon(
                    catalog.favorites.contains(item.id)
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: catalog.favorites.contains(item.id)
                        ? accent2
                        : Colors.white,
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 9,
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _row(String title, List<MediaItem> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(title),
        SizedBox(
          height: 208,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: entries.length,
            itemBuilder: (_, index) => _posterCard(entries[index]),
          ),
        ),
      ],
    );
  }

  Widget _posterCard(MediaItem item) => SizedBox(
        width: 142,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    InkWell(
                      onTap: () => _open(item),
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: panel2,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: outline),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: item.image.isNotEmpty
                            ? Image.network(
                                item.image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const _PosterFallback(),
                              )
                            : const _PosterFallback(),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient:
                              const LinearGradient(colors: [accent, accent2]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.kind == MediaKind.movie ? 'FILME' : 'SÉRIE',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: IconButton(
                        tooltip: catalog.favorites.contains(item.id)
                            ? 'Desfavoritar'
                            : 'Favoritar',
                        onPressed: () async {
                          await catalog.toggleFavorite(item);
                          if (mounted) setState(() {});
                        },
                        icon: Icon(
                          catalog.favorites.contains(item.id)
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: catalog.favorites.contains(item.id)
                              ? accent2
                              : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
}

class _WordMark extends StatelessWidget {
  const _WordMark({this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!large) ...[
            const _BrandMark(size: 38),
            const SizedBox(width: 10),
          ],
          Text(
            'Stream',
            style: TextStyle(
              fontSize: large ? 36 : 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [accent, accent2],
            ).createShader(bounds),
            child: Text(
              'SD',
              style: TextStyle(
                fontSize: large ? 36 : 27,
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          ),
        ],
      );
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
            BoxShadow(
              color: Color(0x4428B8FF),
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: size * .62,
        ),
      );
}

class _SettingsBrand extends StatelessWidget {
  const _SettingsBrand();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: outline),
        ),
        child: const Row(
          children: [
            _BrandMark(size: 48),
            SizedBox(width: 13),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WordMark(),
                SizedBox(height: 2),
                Text(
                  'Sua TV, do seu jeito.',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ],
        ),
      );
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) => Container(
        color: panel2,
        alignment: Alignment.center,
        child: const Icon(
          Icons.play_circle_outline_rounded,
          size: 46,
          color: Colors.white38,
        ),
      );
}

class _MediaSearch extends SearchDelegate<MediaItem?> {
  _MediaSearch(this.items, this.onOpen);

  final List<MediaItem> items;
  final void Function(MediaItem) onOpen;

  @override
  String get searchFieldLabel => 'Buscar no catálogo';

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear),
        )
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back),
      );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final matches = items
        .where(
          (e) =>
              e.name.toLowerCase().contains(query.toLowerCase()) ||
              e.group.toLowerCase().contains(query.toLowerCase()),
        )
        .take(100)
        .toList();

    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (_, i) => ListTile(
        leading: const Icon(Icons.play_circle_outline),
        title: Text(matches[i].name),
        subtitle: Text(matches[i].group),
        onTap: () {
          final item = matches[i];
          close(context, item);
          Future<void>.delayed(Duration.zero, () => onOpen(item));
        },
      ),
    );
  }
}
