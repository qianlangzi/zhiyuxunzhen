import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/utils/feedback.dart';
import '../textbook/ebook_reader_screen.dart';

/// 学习资料查看页（作业 MATERIAL 任务项）
///
/// 按资料类型分流：pdf/图片走电子书阅读器，mp4 视频内建播放，
/// mp3 音频内建播放，ppt 等暂不支持在线预览（提示教师发 PDF 版）。
class MaterialViewScreen extends StatefulWidget {
  const MaterialViewScreen({
    super.key,
    required this.title,
    required this.fileUrl,
    this.materialType = '',
  });

  final String title;
  final String fileUrl;
  final String materialType;

  @override
  State<MaterialViewScreen> createState() => _MaterialViewScreenState();
}

class _MaterialViewScreenState extends State<MaterialViewScreen> {
  String get _type => widget.materialType.toLowerCase();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_type == 'pdf' ||
          _type == 'image' ||
          widget.fileUrl.toLowerCase().endsWith('.pdf')) {
        // pdf/图片直接进阅读器
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => EbookReaderScreen(
            title: widget.title,
            fileUrl: widget.fileUrl,
          ),
        ));
      } else if (_type != 'mp4' && _type != 'mp3') {
        AppFeedback.info(context, '该类型资料暂不支持在线预览，请联系老师提供 PDF 或音视频版本');
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_type == 'mp4') {
      return _VideoPlayerScreen(title: widget.title, url: widget.fileUrl);
    }
    if (_type == 'mp3') {
      return _AudioPlayerScreen(title: widget.title, url: widget.fileUrl);
    }
    // pdf/image 会 pushReplacement 跳走；ppt 等短暂展示 loading
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      appBar: AppBar(
        title: Text(widget.title,
            style: TextStyle(fontSize: 15, color: AppColors.textOf(context))),
        backgroundColor: AppColors.bgOf(context),
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

// ================= 视频 =================

class _VideoPlayerScreen extends StatefulWidget {
  const _VideoPlayerScreen({required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await c.initialize();
      await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _ready = true;
      });
    } catch (e) {
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _error = '视频加载失败，请检查网络后重试');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title,
            style: const TextStyle(fontSize: 15, color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: !_ready
            ? (_error != null
                ? Text(_error!,
                    style: const TextStyle(color: Colors.white70, fontSize: 13))
                : const CircularProgressIndicator(color: Colors.white70))
            : AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
      ),
      floatingActionButton: !_ready
          ? null
          : FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () {
                setState(() {
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                  }
                });
              },
              child: Icon(
                _controller!.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
            ),
    );
  }
}

// ================= 音频 =================

class _AudioPlayerScreen extends StatefulWidget {
  const _AudioPlayerScreen({required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<_AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<_AudioPlayerScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setSourceUrl(widget.url);
      _player.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        setState(() => _playing = state == PlayerState.playing);
      });
      _player.onPositionChanged.listen((p) {
        if (!mounted) return;
        setState(() => _position = p);
      });
      _player.onDurationChanged.listen((d) {
        if (!mounted) return;
        setState(() {
          _duration = d;
          _ready = true;
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '音频加载失败，请检查网络后重试');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      appBar: AppBar(
        title: Text(widget.title,
            style: TextStyle(fontSize: 15, color: AppColors.textOf(context))),
        backgroundColor: AppColors.bgOf(context),
      ),
      body: Center(
        child: _error != null
            ? Text(_error!,
                style: TextStyle(fontSize: 13, color: AppColors.text2Of(context)))
            : Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.mossTintOf(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.headphones_rounded,
                          size: 44, color: AppColors.primaryOf(context)),
                    ),
                    const SizedBox(height: 28),
                    Slider(
                      value: _duration.inMilliseconds > 0 &&
                              _position.inMilliseconds <= _duration.inMilliseconds
                          ? _position.inMilliseconds.toDouble()
                          : 0,
                      max: _duration.inMilliseconds.toDouble(),
                      activeColor: AppColors.primaryOf(context),
                      onChanged: (v) =>
                          _player.seek(Duration(milliseconds: v.toInt())),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        MonoText(_fmt(_position),
                            fontSize: 10, color: AppColors.text3Of(context)),
                        MonoText(_fmt(_duration),
                            fontSize: 10, color: AppColors.text3Of(context)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    IconButton(
                      onPressed: _ready
                          ? () {
                              if (_playing) {
                                _player.pause();
                              } else {
                                _player.resume();
                              }
                            }
                          : null,
                      iconSize: 56,
                      icon: Icon(
                        _playing
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        color: AppColors.primaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
