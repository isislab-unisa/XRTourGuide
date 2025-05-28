import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

class CustomAudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  const CustomAudioPlayerWidget({Key? key, required this.audioUrl})
    : super(key: key);

  @override
  State<CustomAudioPlayerWidget> createState() =>
      _CustomAudioPlayerWidgetState();
}

class _CustomAudioPlayerWidgetState extends State<CustomAudioPlayerWidget> {
  late AudioPlayer _audioPlayer;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      if (widget.audioUrl.startsWith('http')) {
        await _audioPlayer.setUrl(widget.audioUrl);
      } else {
        await _audioPlayer.setAsset(widget.audioUrl);
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      print("Error loading audio: $e");
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_hasError)
      return const Center(
        child: Text(
          "Could not load audio.",
          style: TextStyle(color: Colors.red),
        ),
      );

    return StreamBuilder<PlayerState>(
      stream: _audioPlayer.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processingState = playerState?.processingState;
        final playing = playerState?.playing;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering)
              const CircularProgressIndicator()
            else if (playing != true)
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: _audioPlayer.play,
              )
            else
              IconButton(
                icon: const Icon(Icons.pause),
                onPressed: _audioPlayer.pause,
              ),
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _audioPlayer.stop,
            ),
            // Optional: Display duration and position
          ],
        );
      },
    );
  }
}

// class AudioMarkdownBuilder extends MarkdownElementBuilder {
//   AudioMarkdownBuilder() : super(textStyle: const TextStyle());

//   @override
//   bool get isBlock => true;
//   @override
//   List<String> get matchTypes => const <String>['audio']; // Matches <audio> tag

//   @override
//   Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
//     final String? src = element.attributes['src'];
//     if (src == null || src.isEmpty) {
//       return const Text(
//         'Audio source not specified',
//         style: TextStyle(color: Colors.red),
//       );
//     }
//     return CustomAudioPlayerWidget(audioUrl: src);
//   }
// }
