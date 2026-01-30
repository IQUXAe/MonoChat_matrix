import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
// import 'package:monochat/utils/client_download_extension.dart';
import 'package:monochat/ui/widgets/mxc_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class VideoBubble extends StatefulWidget {
  final Event event;
  final bool isMe;
  final Client client;

  const VideoBubble({
    super.key,
    required this.event,
    required this.isMe,
    required this.client,
  });

  @override
  State<VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<VideoBubble> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitializing = false;
  String? _error;

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    if (_isInitializing || _videoPlayerController != null) return;

    setState(() {
      _isInitializing = true;
      _error = null;
    });

    try {
      // 1. Download and Decrypt (if needed)
      // This helper handles both encrypted (file) and unencrypted (url) events correctly.
      final matrixFile = await widget.event.downloadAndDecryptAttachment();

      // 2. Write to Temp File
      // Video players usually need a file path, they struggle with raw bytes or custom streams.
      final tempDir = await getTemporaryDirectory();
      final filename =
          widget.event.content.tryGet<String>('body') ?? 'video.mp4';
      // Sanitize filename
      final safeFilename = filename.replaceAll(RegExp(r'[^\w\s\.-]'), '');
      final file = File(
        '${tempDir.path}/${widget.event.eventId}_$safeFilename',
      );

      await file.writeAsBytes(matrixFile.bytes);

      // 3. Initialize Player
      _videoPlayerController = VideoPlayerController.file(file);
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        cupertinoProgressColors: ChewieProgressColors(
          playedColor: CupertinoColors.activeBlue,
          handleColor: CupertinoColors.activeBlue,
          backgroundColor: CupertinoColors.systemGrey,
          bufferedColor: CupertinoColors.systemGrey3,
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: CupertinoColors.activeBlue,
          handleColor: CupertinoColors.activeBlue,
          backgroundColor: CupertinoColors.systemGrey,
          bufferedColor: CupertinoColors.systemGrey3,
        ),
        placeholder: const Center(child: CupertinoActivityIndicator()),
        autoInitialize: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isInitializing = false;
        });
      }
    }
  }

  void _openFullScreenPlayer() {
    // For now, simpler implementation: inline player expands or opens dialog
    // But user requested "Professional", so let's try to play inline or open a modal.

    // If not initialized, initialize and play appropriate UI?
    // Actually, standard pattern is: Show thumbnail with Play button.
    // On Tap -> Initialize player and show it.

    if (_videoPlayerController == null) {
      _initializeVideo();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Info for thumbnail ratio
    final info = widget.event.content['info'] as Map?;
    final w = info?['w'] as int?;
    final h = info?['h'] as int?;

    var aspectRatio = 16 / 9;
    if (w != null && h != null && h > 0) {
      aspectRatio = w / h;
    }

    double width = 240;
    var height = width / aspectRatio;

    // Constraints
    if (width > 300) {
      width = 300;
      height = width / aspectRatio;
    }

    if (_chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized) {
      return Container(
        width: width,
        height: height,
        color: Colors.black,
        child: Chewie(controller: _chewieController!),
      );
    }

    if (_isInitializing) {
      return Container(
        width: width,
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        alignment: Alignment.center,
        child: const CupertinoActivityIndicator(),
      );
    }

    if (_error != null) {
      return Container(
        width: width,
        height: height,
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        alignment: Alignment.center,
        child: const Icon(
          CupertinoIcons.exclamationmark_triangle,
          color: CupertinoColors.destructiveRed,
        ),
      );
    }

    // Thumbnail state
    return GestureDetector(
      onTap: _openFullScreenPlayer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Placeholder / Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: CupertinoColors.secondarySystemBackground
                        .resolveFrom(context),
                  ),
                  if ((widget.event.content['info'] as Map?)?['thumbnail_url']
                      is String)
                    MxcImage(
                      uri: Uri.tryParse(
                        (widget.event.content['info'] as Map)['thumbnail_url']
                            as String,
                      ),
                      client: widget.client,
                      fit: BoxFit.cover,
                      isThumbnail: true,
                      width: width,
                      height: height,
                    ),
                  const Center(
                    child: Icon(
                      CupertinoIcons.play_circle_fill,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
