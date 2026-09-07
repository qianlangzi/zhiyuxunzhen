import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../core/config/api_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/feedback.dart';
import '../../../shared/widgets/app_widgets.dart';

/// 学习资料 · 单个文件在线预览（图片 / 视频 / 音频 / 下载兜底）
///
/// PDF 由调用方在资料详情页直接 push `EbookReaderScreen`（pdfx），本页负责其余类型：
/// - image → 全屏看大图
/// - video → video_player 播放
/// - audio → audioplayers 播放
/// - download/其它 → 下载后通过系统分享打开
class CourseMaterialPreviewScreen extends StatefulWidget {
  const CourseMaterialPreviewScreen({
    super.key,
    required this.type,
    required this.title,
    required this.url,
  });

  /// 类型归一后的预览类型：image / video / audio / download
  final String type;
  final String title;
  final String url;

  @override
  State<CourseMaterialPreviewScreen> createState() =>
      _CourseMaterialPreviewScreenState();
}

class _CourseMaterialPreviewScreenState
    extends State<CourseMaterialPreviewScreen> {
  String get _fullUrl {
    final raw = widget.url;
    if (Uri.tryParse(raw)?.hasScheme ?? false) return raw;
    const base = ApiConfig.apiBaseUrl;
    if (raw.startsWith('/')) return '$base$raw';
    return '$base/$raw';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppBackAppBar(title: widget.title, onBack: () => Navigator.pop(context)),
            Expanded(
              child: switch (widget.type) {
                'image' => _buildImage(),
                'video' => _VideoView(url: _fullUrl),
                'audio' => _AudioView(url: _fullUrl, title: widget.title),
                _ => _buildDownloadFallback(),
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 图片 ----------
  Widget _buildImage() {
    if (widget.url.isEmpty) return _hint('图片地址为空');
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: _fullUrl,
          fit: BoxFit.contain,
          progressIndicatorBuilder: (c, _, p) {
            final pro = p.progress;
            return _hint(pro == null
                ? '加载图片中…'
                : '加载中 ${(pro * 100).toStringAsFixed(0)}%');
          },
          errorWidget: (c, _, e) => _hint('图片加载失败，请检查网络'),
        ),
      ),
    );
  }

  // ---------- 下载分享兜底（ppt / 未知类型） ----------
  Widget _buildDownloadFallback() {
    if (widget.url.isEmpty) return _hint('文件地址为空');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_zip_outlined,
                size: 56, color: AppColors.amberOf(context)),
            const SizedBox(height: 16),
            Text('该类型暂不支持在线预览',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOf(context))),
            const SizedBox(height: 8),
            Text('已为你生成下载，点击下方按钮通过系统应用打开课件',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5, height: 1.6, color: AppColors.text3Of(context))),
            const SizedBox(height: 24),
            AppPrimaryButton(
              label: '下载并分享',
              fullWidth: true,
              icon: const Icon(Icons.ios_share_rounded, size: 16),
              onPressed: _downloadAndShare,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadAndShare() async {
    try {
      final dir = await getTemporaryDirectory();
      final fileName = _fileNameOf(widget.url);
      final file = File('${dir.path}/$fileName');
      if (await file.exists()) await file.delete();
      await ApiClient.instance.download(
        _fullUrl,
        file.path,
        options: Options(
          validateStatus: (s) => s != null && s >= 200 && s < 400,
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
      await Share.shareXFiles([XFile(file.path)], text: widget.title);
    } on DioException catch (e) {
      if (!mounted) return;
      AppFeedback.info(context, e.response?.statusCode == 404
          ? '文件不存在，请确认资料已上传'
          : '下载失败：${e.message}');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.info(context, '下载失败：$e');
    }
  }

  String _fileNameOf(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.pathSegments ?? const [];
    if (path.isNotEmpty) {
      final last = path.last.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      if (last.isNotEmpty) return last;
    }
    return 'material_${DateTime.now().millisecondsSinceEpoch}.bin';
  }

  Widget _hint(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.text2Of(context))),
      ),
    );
  }
}

/// 视频播放器（video_player）
class _VideoView extends StatefulWidget {
  const _VideoView({required this.url});
  final String url;

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  VideoPlayerController? _controller;
  bool _init = false;
  String? _error;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = c;
    c.addListener(_onTick);
    try {
      await c.initialize();
      await c.setLooping(false);
      await c.play();
    } catch (e) {
      if (mounted) setState(() => _error = '视频加载失败：$e');
    }
    if (mounted) setState(() => _init = true);
  }

  void _onTick() {
    if (!mounted || _dragging) return;
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _fmt(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (!_init) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || c == null || !c.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(_error ?? '视频加载失败',
              style: TextStyle(fontSize: 13, color: AppColors.text2Of(context))),
        ),
      );
    }
    final pos = c.value.position.inMilliseconds;
    final dur = c.value.duration.inMilliseconds;
    final progress = dur > 0 ? pos / dur : 0.0;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio,
              child: GestureDetector(
                onTap: () => c.value.isPlaying ? c.pause() : c.play(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(c),
                    if (!c.value.isPlaying)
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 36),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Row(
            children: [
              MonoText(_fmt(pos), fontSize: 11, color: AppColors.text3Of(context)),
              Expanded(
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChangeStart: (_) => setState(() => _dragging = true),
                  onChanged: (v) => c.seekTo(
                      Duration(milliseconds: (dur * v).round())),
                  onChangeEnd: (_) => setState(() => _dragging = false),
                ),
              ),
              MonoText(_fmt(dur), fontSize: 11, color: AppColors.text3Of(context)),
            ],
          ),
        ),
      ],
    );
  }
}

/// 音频播放器（audioplayers）
class _AudioView extends StatefulWidget {
  const _AudioView({required this.url, required this.title});
  final String url;
  final String title;

  @override
  State<_AudioView> createState() => _AudioViewState();
}

class _AudioViewState extends State<_AudioView> {
  final _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
    try {
      await _player.setSourceUrl(widget.url);
      _player.resume();
    } catch (e) {
      if (mounted) setState(() => _error = '音频加载失败：$e');
    } finally {
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(_error!,
              style: TextStyle(fontSize: 13, color: AppColors.text2Of(context))),
        ),
      );
    }
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                if (_playing) {
                  _player.pause();
                } else {
                  _player.resume();
                }
              },
              child: Container(
                width: 92,
                height: 92,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryOf(context),
                  shape: BoxShape.circle,
                  boxShadow: AppShadow.card(context),
                ),
                child: _playing
                    ? const Icon(Icons.pause_rounded, color: Colors.white, size: 40)
                    : const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOf(context))),
            const SizedBox(height: 20),
            Slider(
              value: progress,
              onChanged: (v) => _player
                  .seek(Duration(milliseconds: (_duration.inMilliseconds * v).round())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  MonoText(_fmt(_position),
                      fontSize: 11, color: AppColors.text3Of(context)),
                  MonoText(_fmt(_duration),
                      fontSize: 11, color: AppColors.text3Of(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}