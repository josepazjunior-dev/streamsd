import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/media_item.dart';
import '../services/catalog_store.dart';

const _accent = Color(0xFF159DFF);
const _accent2 = Color(0xFF8B35F5);
const _panel = Color(0xE8121721);
const _outline = Color(0xFF2B3448);

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.item});

  final MediaItem item;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final VideoPlayerController controller;
  bool loading = true;
  bool muted = false;
  String? error;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.item.url),
      httpHeaders: CatalogStore.requestHeaders,
    );
    controller.addListener(_onUpdate);
    _start();
  }

  void _onUpdate() {
    if (!mounted) return;
    final value = controller.value;
    if (value.hasError) {
      setState(() {
        error = value.errorDescription ?? 'Falha ao reproduzir o stream.';
        loading = false;
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _start() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await controller.initialize().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      await controller.play();
      if (mounted) setState(() => loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Stream indisponível ou formato não suportado.';
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    controller.removeListener(_onUpdate);
    controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initialized = controller.value.isInitialized;
    final duration = initialized ? controller.value.duration : Duration.zero;
    final position = initialized ? controller.value.position : Duration.zero;
    final canSeek = duration.inMilliseconds > 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: loading
                  ? const CircularProgressIndicator()
                  : error != null
                      ? _errorView()
                      : AspectRatio(
                          aspectRatio: controller.value.aspectRatio > 0
                              ? controller.value.aspectRatio
                              : 16 / 9,
                          child: VideoPlayer(controller),
                        ),
            ),
            if (!loading && error == null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: .62),
                        Colors.transparent,
                        Colors.black.withValues(alpha: .7),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, .48, 1],
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _glassButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Fechar',
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: _outline),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.live_tv_rounded,
                              color: _accent, size: 21),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              widget.item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (widget.item.kind == MediaKind.channel)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6213A),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!loading && error == null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 18,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(color: _outline),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (canSeek)
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: _accent,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: _accent,
                            overlayColor: _accent.withValues(alpha: .18),
                            trackHeight: 3,
                          ),
                          child: Slider(
                            value: position.inMilliseconds
                                .clamp(0, duration.inMilliseconds)
                                .toDouble(),
                            max: duration.inMilliseconds.toDouble(),
                            onChanged: (value) {
                              controller.seekTo(
                                Duration(milliseconds: value.round()),
                              );
                            },
                          ),
                        )
                      else
                        Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_accent, _accent2],
                            ),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          _controlButton(
                            icon: controller.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            onTap: () {
                              controller.value.isPlaying
                                  ? controller.pause()
                                  : controller.play();
                            },
                          ),
                          const SizedBox(width: 10),
                          _controlButton(
                            icon: muted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            onTap: () {
                              muted = !muted;
                              controller.setVolume(muted ? 0 : 1);
                              setState(() {});
                            },
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: _outline),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  widget.item.kind == MediaKind.channel
                                      ? Icons.wifi_tethering_rounded
                                      : Icons.high_quality_rounded,
                                  color: _accent,
                                  size: 18,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  widget.item.kind == MediaKind.channel
                                      ? 'SD'
                                      : 'Automático',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() => Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 50, color: _accent),
              const SizedBox(height: 16),
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  await controller.dispose();
                  if (mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Voltar'),
              ),
            ],
          ),
        ),
      );

  Widget _glassButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: _panel,
          side: const BorderSide(color: _outline),
        ),
        icon: Icon(icon),
      );

  Widget _controlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_accent, _accent2]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white),
        ),
      );
}
