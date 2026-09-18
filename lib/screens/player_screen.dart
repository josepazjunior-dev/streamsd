import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/media_item.dart';

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
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.item.url));
    controller.addListener(_onUpdate);
    _start();
  }

  void _onUpdate() {
    if (!mounted) return;
    final value = controller.value;
    if (value.hasError) {
      setState(() { error = value.errorDescription ?? 'Falha ao reproduzir o stream.'; loading = false; });
    } else { setState(() {}); }
  }

  Future<void> _start() async {
    setState(() { loading = true; error = null; });
    try {
      await controller.initialize().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      await controller.play();
      if (mounted) setState(() => loading = false);
    } catch (_) {
      if (mounted) setState(() { error = 'Stream indisponível ou formato não suportado.'; loading = false; });
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(child: Stack(children: [
      Center(child: loading ? const CircularProgressIndicator() : error != null
        ? Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off, size: 50), const SizedBox(height: 16),
          Text(error!, textAlign: TextAlign.center), const SizedBox(height: 12),
          FilledButton(onPressed: () async {
            await controller.dispose();
            if (mounted) Navigator.pop(context);
          }, child: const Text('Voltar')),
        ]))
        : AspectRatio(aspectRatio: controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 16 / 9,
          child: VideoPlayer(controller))),
      Positioned(top: 8, left: 4, right: 12, child: Row(children: [
        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
        Expanded(child: Text(widget.item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold))),
        IconButton(tooltip: muted ? 'Ativar som' : 'Silenciar', onPressed: () {
          muted = !muted; controller.setVolume(muted ? 0 : 1); setState(() {});
        }, icon: Icon(muted ? Icons.volume_off : Icons.volume_up)),
      ])),
      if (!loading && error == null) Center(child: IconButton(
        iconSize: 62, onPressed: () { controller.value.isPlaying ? controller.pause() : controller.play(); },
        icon: Icon(controller.value.isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline),
      )),
    ])),
  );
}
