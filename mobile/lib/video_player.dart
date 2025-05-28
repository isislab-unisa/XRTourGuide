import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

class CustomVideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const CustomVideoPlayerWidget({Key? key, required this.videoUrl})
    : super(key: key);

  @override
  State<CustomVideoPlayerWidget> createState() =>
      _CustomVideoPlayerWidgetState();
}

class _CustomVideoPlayerWidgetState extends State<CustomVideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController =
          widget.videoUrl.startsWith('http')
              ? VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
              : VideoPlayerController.asset(widget.videoUrl);

      await _videoPlayerController.initialize();
      if (!mounted) return;

      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController,
          autoPlay: false,
          looping: false,
          // You can add more customization options here
        );
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        print('Error initializing video player: $e');
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasError) {
      return const Center(
        child: Text(
          'Could not load video.',
          style: TextStyle(color: Colors.red),
        ),
      );
    }
    if (_chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized) {
      return AspectRatio(
        aspectRatio: _videoPlayerController.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      );
    } else {
      return const Center(child: Text('Initializing video...'));
    }
  }
}


// class VideoMarkdownBuilder extends MarkdownElementBuilder {
//   VideoMarkdownBuilder()
//     : super(textStyle: const TextStyle()); // Base textStyle, can be anything

//   @override
//   bool get isBlock => true;

//   @override
//   List<String> get matchTypes => const <String>['video']; // Matches <video> tag

//   @override
//   Widget? visitElementAfter(Element element, TextStyle? preferredStyle) {
//     final String? src = element.attributes['src'];
//     if (src == null || src.isEmpty) {
//       return const Text(
//         'Video source not specified',
//         style: TextStyle(color: Colors.red),
//       );
//     }
//     return CustomVideoPlayerWidget(videoUrl: src);
//   }
// }
