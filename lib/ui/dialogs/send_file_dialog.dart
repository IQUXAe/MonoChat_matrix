import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:cross_file/cross_file.dart';
import 'package:matrix/matrix.dart';
import 'package:mime/mime.dart';
import 'package:gap/gap.dart';

import '../../utils/size_string.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:provider/provider.dart';

/// iOS-styled dialog for sending files with compression options.
///
/// Displays file previews, allows toggling compression,
/// and provides a polished send experience.
class SendFileDialog extends StatefulWidget {
  final Room room;
  final List<XFile> files;
  final Future<void> Function(List<XFile> files, bool compress) onSend;

  const SendFileDialog({
    super.key,
    required this.room,
    required this.files,
    required this.onSend,
  });

  /// Show the dialog and return true if files were sent
  static Future<bool?> show(
    BuildContext context, {
    required Room room,
    required List<XFile> files,
    required Future<void> Function(List<XFile> files, bool compress) onSend,
  }) {
    return showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) =>
          SendFileDialog(room: room, files: files, onSend: onSend),
    );
  }

  @override
  State<SendFileDialog> createState() => _SendFileDialogState();
}

class _SendFileDialogState extends State<SendFileDialog> {
  bool _compress = true;
  bool _isSending = false;
  late List<XFile> _files;

  @override
  void initState() {
    super.initState();
    _files = List.from(widget.files);
  }

  String? _getUniqueFileType() {
    final types = _files
        .map((f) => f.mimeType ?? lookupMimeType(f.name))
        .map((m) => m?.split('/').first)
        .toSet();
    return types.length == 1 ? types.first : null;
  }

  Future<String> _calcCombinedFileSize() async {
    final lengths = await Future.wait(_files.map((f) => f.length()));
    return lengths.fold<double>(0, (p, l) => p + l).sizeString;
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
    });
    if (_files.isEmpty) {
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _send() async {
    if (_isSending) return;

    setState(() => _isSending = true);

    try {
      await widget.onSend(_files, _compress);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;
    final uniqueType = _getUniqueFileType();
    final isImage = uniqueType == 'image';
    final isVideo = uniqueType == 'video';

    String title;
    final l10n = AppLocalizations.of(context)!;
    if (isImage) {
      title = _files.length == 1
          ? l10n.sendPhoto
          : l10n.sendPhotos(_files.length);
    } else if (isVideo) {
      title = l10n.sendVideo;
    } else {
      title = _files.length == 1
          ? l10n.sendFile
          : l10n.sendFiles(_files.length);
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.scaffoldBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 5,
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: palette.secondaryText.withValues(
                  alpha: 0.2,
                ), // softer handle
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
            ),

            Container(height: 0.5, color: palette.separator),

            // Preview area
            if (isImage) _buildImagePreviews() else _buildFileSummary(),

            Container(height: 0.5, color: palette.separator),

            // Compression toggle (for images and videos)
            if (isImage || isVideo) _buildCompressionToggle(),

            // File size info
            FutureBuilder<String>(
              future: _calcCombinedFileSize(),
              builder: (context, snapshot) {
                final size = snapshot.data ?? l10n.calculating;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.doc,
                        size: 16,
                        color: palette.secondaryText,
                      ),
                      const Gap(8),
                      Text(
                        l10n.totalSize(size),
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.secondaryText,
                        ),
                      ),
                      if (_compress && isImage) ...[
                        const Gap(8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: CupertinoColors.activeGreen.withOpacity(
                              0.15,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.willBeCompressed,
                            style: const TextStyle(
                              fontSize: 11,
                              color: CupertinoColors.activeGreen,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

            Container(height: 0.5, color: palette.separator),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: palette.inputBackground,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: _isSending
                          ? null
                          : () => Navigator.pop(context, false),
                      child: Text(
                        l10n.cancel,
                        style: TextStyle(
                          color: palette.text,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    flex: 2,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: palette.primary,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: _isSending ? null : _send,
                      child: _isSending
                          ? const CupertinoActivityIndicator(
                              color: CupertinoColors.white,
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  CupertinoIcons.paperplane_fill,
                                  size: 18,
                                  color: CupertinoColors.white,
                                ),
                                const Gap(8),
                                Text(
                                  l10n.send,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                              ],
                            ),
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

  Widget _buildImagePreviews() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        scrollDirection: Axis.horizontal,
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final file = _files[index];
          return Padding(
            padding: EdgeInsets.only(right: index < _files.length - 1 ? 12 : 0),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: _files.length == 1 ? 280 : 160,
                    height: 168,
                    color: context
                        .watch<ThemeController>()
                        .palette
                        .inputBackground,
                    child: kIsWeb
                        ? FutureBuilder<Uint8List>(
                            future: file.readAsBytes(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CupertinoActivityIndicator(),
                                );
                              }
                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                cacheWidth: 320,
                              );
                            },
                          )
                        : Image.file(
                            File(file.path),
                            fit: BoxFit.cover,
                            cacheWidth: 320,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                CupertinoIcons.photo,
                                size: 48,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ),
                  ),
                ),
                // Remove button
                if (_files.length > 1)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _removeFile(index),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: CupertinoColors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.xmark,
                          size: 16,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFileSummary() {
    final fileTypes = _files
        .map((f) => f.name.split('.').last)
        .toSet()
        .join(', ')
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: context.watch<ThemeController>().palette.inputBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getFileIcon(),
              size: 28,
              color: context.read<ThemeController>().palette.primary,
            ),
          ),
          const Gap(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _files.length == 1
                      ? _files.first.name
                      : '${_files.length} files',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: context.watch<ThemeController>().palette.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(4),
                Text(
                  fileTypes,
                  style: TextStyle(
                    fontSize: 13,
                    color: context
                        .watch<ThemeController>()
                        .palette
                        .secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon() {
    final type = _getUniqueFileType();
    switch (type) {
      case 'video':
        return CupertinoIcons.videocam_fill;
      case 'audio':
        return CupertinoIcons.music_note_2;
      case 'application':
        return CupertinoIcons.doc_fill;
      default:
        return CupertinoIcons.doc_fill;
    }
  }

  Widget _buildCompressionToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.compress,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: context.watch<ThemeController>().palette.text,
                  ),
                ),
                const Gap(2),
                Text(
                  AppLocalizations.of(context)!.compressDescription,
                  style: TextStyle(
                    fontSize: 13,
                    color: context
                        .watch<ThemeController>()
                        .palette
                        .secondaryText,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: _compress,
            onChanged: (v) => setState(() => _compress = v),
            activeTrackColor: CupertinoColors.activeGreen,
          ),
        ],
      ),
    );
  }
}
