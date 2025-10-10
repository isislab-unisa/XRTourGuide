// lib/video_player_widget.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/app_colors.dart'; // Import AppColors

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool isLocalFile;

  const VideoPlayerWidget({Key? key, required this.videoUrl, this.isLocalFile = false}) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (widget.isLocalFile) {      
      _videoPlayerController = VideoPlayerController.file(
        File(widget.videoUrl),
      );
    } else {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
    }
    // _videoPlayerController = VideoPlayerController.networkUrl(
    //   Uri.parse(widget.videoUrl),
    // );
    await _videoPlayerController.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay:
          false, // Don't autoplay when embedded to avoid performance issues with multiple players
      looping: false,
      aspectRatio: _videoPlayerController.value.aspectRatio,
      showControls: true,
      allowFullScreen: true,
      // You can customize controls color/theme if needed
      materialProgressColors: ChewieProgressColors(
        playedColor: AppColors.primary,
        handleColor: AppColors.primary,
        backgroundColor: AppColors.divider,
        bufferedColor: AppColors.lightGrey,
      ),
    );
    if (mounted) {
      setState(() {});
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Video Tour',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: AppColors.textPrimary),
          ),
        ),
        AspectRatio(
          aspectRatio:
              _chewieController?.aspectRatio ??
              16 / 9, // Default aspect ratio while loading
          child:
              _chewieController != null &&
                      _chewieController!
                          .videoPlayerController
                          .value
                          .isInitialized
                  ? Chewie(controller: _chewieController!)
                  : Container(
                    color: AppColors.secondaryBackground,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
        ),
      ],
    );
  }
}
