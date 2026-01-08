import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors; // for some utils
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:monochat/ui/widgets/mxc_image.dart';
import 'package:matrix/matrix.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';

class FullScreenImageViewer extends StatefulWidget {
  final List<Event> images;
  final int initialIndex;
  final Client client;

  const FullScreenImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.client,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _saveCurrent() async {
    if (_saving) return; // Prevent double taps

    // 1. Ask for confirmation
    final bool? confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: Text(AppLocalizations.of(context)!.saveImageTitle),
        content: Text(AppLocalizations.of(context)!.saveImageContent),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(c, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(c, true),
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);

    try {
      final event = widget.images[_currentIndex];

      final bool isEncrypted =
          event.content['file'] != null || event.type == EventTypes.Encrypted;

      final List<int> bytes;
      String fileName =
          event.content.tryGet<String>('body') ?? 'matrix_image.jpg';
      // Sanitize filename
      fileName = fileName.replaceAll(RegExp(r'[^\w\s\.-]'), '');

      // Download/Decrypt logic
      if (isEncrypted) {
        final matrixFile = await event.downloadAndDecryptAttachment();
        bytes = matrixFile.bytes;
      } else {
        final uri = Uri.tryParse(event.content.tryGet<String>('url') ?? '');
        if (uri == null) throw Exception("No URL found");
        final httpUri = await uri.getDownloadUri(widget.client);
        final headers = <String, String>{};
        if (widget.client.accessToken != null) {
          headers['Authorization'] = 'Bearer ${widget.client.accessToken}';
        }
        final resp = await http.get(httpUri, headers: headers);
        if (resp.statusCode != 200) throw Exception("HTTP ${resp.statusCode}");
        bytes = resp.bodyBytes;
      }

      // Platform specific saving
      if (Platform.isAndroid || Platform.isIOS) {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) await Gal.requestAccess();
        await Gal.putImageBytes(Uint8List.fromList(bytes), name: fileName);
      } else {
        // Desktop (Linux, etc) logic
        String? outputFile;
        try {
          outputFile = await FilePicker.platform.saveFile(
            dialogTitle: 'Save Image',
            fileName: fileName,
            type: FileType.image,
          );
        } catch (e) {
          debugPrint('FilePicker failed: $e');
        }

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(bytes);
        } else {
          // Fallback if Picker failed (e.g. missing Portal on Linux)
          // We don't validly know if user canceled vs picker crashed if it throws.
          // But if it threw, outputFile is null.
          // We should try 'Downloads' if the picker specifically failed.

          try {
            final downloads = await getDownloadsDirectory();
            final docs = await getApplicationDocumentsDirectory();
            final dir = downloads ?? docs;

            final path = '${dir.path}/$fileName';
            final file = File(path);
            await file.writeAsBytes(bytes);

            if (mounted) {
              showCupertinoDialog(
                context: context,
                builder: (c) => CupertinoAlertDialog(
                  title: Text(AppLocalizations.of(context)!.saved),
                  content: Text(
                    AppLocalizations.of(context)!.systemDialogError(path),
                  ),
                  actions: [
                    CupertinoDialogAction(
                      child: Text(AppLocalizations.of(context)!.ok),
                      onPressed: () => Navigator.pop(c),
                    ),
                  ],
                ),
              );
              return; // Exit here as we showed a custom success message
            }
          } catch (fallbackError) {
            // If even fallback fails, we rethrow/let the main catch handle it.
            throw Exception("Could not save to disk: $fallbackError");
          }
        }
      }

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (c) => CupertinoAlertDialog(
            title: Text(AppLocalizations.of(context)!.saved),
            content: Text(AppLocalizations.of(context)!.imageSavedSuccess),
            actions: [
              CupertinoDialogAction(
                child: Text(AppLocalizations.of(context)!.ok),
                onPressed: () => Navigator.pop(c),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (c) => CupertinoAlertDialog(
            title: Text(AppLocalizations.of(context)!.error),
            content: Text(AppLocalizations.of(context)!.failedToSave(e)),
            actions: [
              CupertinoDialogAction(
                child: Text(AppLocalizations.of(context)!.ok),
                onPressed: () => Navigator.pop(c),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Colors.transparent, // Important for blur
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withOpacity(0.4),
        middle: Text(
          '${_currentIndex + 1} of ${widget.images.length}',
          style: const TextStyle(color: CupertinoColors.white),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.xmark, color: CupertinoColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        trailing: _saving
            ? const CupertinoActivityIndicator(color: CupertinoColors.white)
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _saveCurrent,
                child: const Icon(
                  CupertinoIcons.arrow_down_doc,
                  color: CupertinoColors.white,
                ),
              ),
      ),
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Stack(
          children: [
            // 1. Blurry Background
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(color: CupertinoColors.black.withOpacity(0.8)),
              ),
            ),
            // 2. Gallery
            PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                final event = widget.images[index];
                final uriStr =
                    event.content.tryGet<String>('url') ??
                    (event.content['file'] as Map?)?['url'];
                final uri = uriStr != null ? Uri.tryParse(uriStr) : null;

                return PhotoViewGalleryPageOptions.customChild(
                  child: MxcImage(
                    uri: uri,
                    event: event,
                    client: widget.client,
                    fit: BoxFit.contain,
                    isThumbnail: false,
                  ),
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                  heroAttributes: PhotoViewHeroAttributes(tag: event.eventId),
                );
              },
              itemCount: widget.images.length,
              loadingBuilder: (context, event) => const Center(
                child: CupertinoActivityIndicator(
                  radius: 12,
                  color: CupertinoColors.white,
                ),
              ),
              backgroundDecoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              pageController: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
            // 3. Desktop/Linux Previous/Next buttons (Visible only on Desktop)
            if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
              Positioned.fill(
                child: Row(
                  children: [
                    // Previous Button (Left Zone)
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: () {
                          if (_currentIndex > 0) {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        behavior: HitTestBehavior.translucent,
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          child: _currentIndex > 0
                              ? Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.chevron_left,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    // Center Image Zone (Pass through to PhotoView)
                    const Expanded(flex: 3, child: SizedBox()),
                    // Next Button (Right Zone)
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: () {
                          if (_currentIndex < widget.images.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        behavior: HitTestBehavior.translucent,
                        child: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: _currentIndex < widget.images.length - 1
                              ? Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.chevron_right,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
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
}
