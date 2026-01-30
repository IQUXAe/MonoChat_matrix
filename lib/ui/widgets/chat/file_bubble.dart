import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:gap/gap.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';
import 'package:monochat/utils/matrix_file_extension.dart';

class FileBubble extends StatefulWidget {
  final Event event;
  final bool isMe;

  const FileBubble({super.key, required this.event, required this.isMe});

  @override
  State<FileBubble> createState() => _FileBubbleState();
}

class _FileBubbleState extends State<FileBubble> {
  bool _isDownloading = false;
  double? _progress;

  String get filename => widget.event.content['body'] as String? ?? 'File';
  int? get size => (widget.event.content['info'] as Map?)?['size'] as int?;

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _save() async {
    setState(() {
      _isDownloading = true;
      _progress = null;
    });

    try {
      Uint8List bytes;
      final isEncrypted =
          widget.event.content['file'] != null ||
          widget.event.type == EventTypes.Encrypted;

      // Download
      if (isEncrypted) {
        // Unfortunately downloadAndDecryptAttachment doesn't support progress callback easily
        // We could implement custom decrypt if needed, but for now just await
        final matrixFile = await widget.event.downloadAndDecryptAttachment();
        bytes = matrixFile.bytes;
      } else {
        final url = widget.event.content['url'] as String?;
        if (url == null) {
          throw Exception('No url found');
        }
        final uri = Uri.parse(url);
        final httpUri = await uri.getDownloadUri(widget.event.room.client);

        final client = http.Client();
        final request = http.Request('GET', httpUri);
        final response = await client.send(request);

        final contentLength = response.contentLength;
        final accumulatedBytes = <int>[];

        await for (final chunk in response.stream) {
          accumulatedBytes.addAll(chunk);
          if (contentLength != null && mounted) {
            setState(() {
              _progress = accumulatedBytes.length / contentLength;
            });
          }
        }
        bytes = Uint8List.fromList(accumulatedBytes);
      }

      if (mounted) {
        final matrixFile = MatrixFile(bytes: bytes, name: filename);
        matrixFile.save(context);
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (c) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to download: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(c),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reverted visual style but alignment is handled by parent MessageBubble now.
    // Style: isMe ? activeBlue.withValues(alpha: 0.1) : systemGrey6
    // Style: isMe ? activeBlue.withValues(alpha: 0.1) : systemGrey6
    final bg = widget.isMe
        ? CupertinoColors.white.withValues(alpha: 0.25)
        : CupertinoColors.black.withValues(alpha: 0.05);

    final borderColor = widget.isMe
        ? CupertinoColors.white.withValues(alpha: 0.4)
        : CupertinoColors.black.withValues(alpha: 0.1);

    final textColor = CupertinoColors.label.resolveFrom(context);
    final iconColor = widget.isMe
        ? CupertinoColors.activeBlue
        : CupertinoColors.systemGrey.resolveFrom(context);

    return GestureDetector(
      onTap: _isDownloading ? null : _save,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(iconColor),
            const Gap(12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    filename,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(4),
                  Text(
                    _isDownloading
                        ? '${_progress != null ? (_progress! * 100).toStringAsFixed(0) : "..."}%'
                        : _formatSize(size),
                    style: const TextStyle(
                      color: CupertinoColors
                          .systemGrey, // Always grey for subtitle here
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(Color color) {
    if (_isDownloading) {
      return Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: CircularProgressIndicator(
          value: _progress,
          color: color,
          strokeWidth: 3,
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2), // Subtle background for icon
        shape: BoxShape.circle,
      ),
      child: Icon(CupertinoIcons.doc_fill, color: color, size: 20),
    );
  }
}
