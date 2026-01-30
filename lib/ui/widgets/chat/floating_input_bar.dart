import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show
        Colors,
        InputBorder,
        InputDecoration,
        TextField,
        Material,
        MaterialType;
import 'package:gap/gap.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/chat_controller.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/ui/theme/app_palette.dart';
import 'package:monochat/ui/widgets/mxc_image.dart';

/// A refined, thin floating input bar with Apple-like aesthetics.
class FloatingInputBar extends StatelessWidget {
  final TextEditingController textController;
  final ChatController controller;
  final AppPalette palette;
  final double bottomPadding;
  final VoidCallback onSend;
  final VoidCallback onAttachment;
  final VoidCallback onStateChanged;

  const FloatingInputBar({
    super.key,
    required this.textController,
    required this.controller,
    required this.palette,
    required this.bottomPadding,
    required this.onSend,
    required this.onAttachment,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = textController.text.trim().isNotEmpty;
    // Check for extra content
    final hasExtraContent =
        controller.processingFiles.isNotEmpty ||
        controller.editingEvent != null ||
        controller.replyingTo != null ||
        controller.attachmentDrafts.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: 16, // Widened margins for more compact look
        right: 16,
        top: 8,
        bottom: bottomPadding + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Extra Content Island (Reply, Edit, Uploads)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuint,
            alignment: Alignment.bottomCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: hasExtraContent
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      // Key is crucial for AnimatedSwitcher to detect changes
                      child: _GlassIsland(
                        key: ValueKey(
                          'extra_${controller.processingFiles.length}_${controller.editingEvent?.eventId}_${controller.replyingTo?.eventId}_${controller.attachmentDrafts.length}',
                        ),
                        palette: palette,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (controller.processingFiles.isNotEmpty)
                              _buildProcessingIndicator(),
                            if (controller.editingEvent != null)
                              _buildEditPreview(context)
                            else if (controller.replyingTo != null)
                              _buildReplyPreview(context),
                            if (controller.attachmentDrafts.isNotEmpty)
                              _buildDraftAttachments(context),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // 2. Main Input Island - Thinner and cleaner
          _GlassIsland(
            palette: palette,
            // Thinner padding: vertical 4 instead of 6 or 8
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            borderRadius: 26, // Slightly more rounded (stadium-like)
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attachment Button - Apple Style
                CupertinoButton(
                  padding: const EdgeInsets.only(bottom: 1),
                  onPressed: onAttachment, minimumSize: const Size(34, 34),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: palette.secondaryText.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      CupertinoIcons.add, // Simple thin plus inside circle
                      size: 20,
                      color: palette.text,
                    ),
                  ),
                ),

                const Gap(4),

                // Text Input
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 36),
                    alignment: Alignment.centerLeft,
                    child: Material(
                      type: MaterialType.transparency,
                      child: TextField(
                        controller: textController,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 16,
                          height: 1.3,
                        ),
                        onChanged: (_) => onStateChanged(),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(
                            context,
                          )!.messagePlaceholder,
                          hintStyle: TextStyle(
                            color: palette.secondaryText.withValues(alpha: 0.6),
                          ),
                          isDense: true,
                          // Thinner content padding
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          filled: false,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),

                const Gap(4),

                // Send Button - Apple Style
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: hasText
                      ? CupertinoButton(
                          key: const ValueKey('send'),
                          padding: const EdgeInsets.only(bottom: 1),
                          onPressed: onSend, minimumSize: const Size(34, 34),
                          child: Icon(
                            CupertinoIcons.arrow_up_circle_fill,
                            size: 30, // Slightly smaller, more refined
                            color: palette.primary,
                          ),
                        )
                      : const SizedBox(
                          key: ValueKey('placeholder'),
                          width: 34,
                        ), // Keep space or hide completely? Better to hide but maybe keep layout stable? user likely wants it to feel like iMessage appearing.
                  // iMessage hides it.
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ... ---
  // (Helpers remain largely similar but ensuring they use palette correctly)

  Widget _buildProcessingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          const CupertinoActivityIndicator(radius: 8),
          const Gap(12),
          Expanded(
            child: Text(
              'Uploading ${controller.processingFiles.join(', ')}...',
              style: TextStyle(fontSize: 13, color: palette.secondaryText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditPreview(BuildContext context) {
    return _PreviewContainer(
      palette: palette,
      icon: CupertinoIcons.pencil,
      title: 'Editing',
      body: controller.editingEvent?.body ?? '',
      onCancel: () {
        controller.cancelEditing();
        textController.clear();
        onStateChanged();
      },
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    final senderName =
        controller.replyingTo?.senderFromMemoryOrFallback.calcDisplayname() ??
        AppLocalizations.of(context)!.unknownUser;

    Widget? leading;
    if (controller.replyingTo?.messageType == MessageTypes.Image) {
      leading = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: palette.inputBackground,
        ),
        clipBehavior: Clip.hardEdge,
        child: MxcImage(
          event: controller.replyingTo,
          isThumbnail: true,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
        ),
      );
    }

    return _PreviewContainer(
      palette: palette,
      icon: CupertinoIcons.reply,
      customLeading: leading,
      title: AppLocalizations.of(context)!.replyingTo(senderName),
      body: controller.replyingTo?.body ?? '',
      onCancel: () {
        controller.setReplyTo(null);
        onStateChanged();
      },
    );
  }

  Widget _buildDraftAttachments(BuildContext context) {
    return Container(
      height: 72, // Slightly more compact
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        scrollDirection: Axis.horizontal,
        itemCount: controller.attachmentDrafts.length,
        separatorBuilder: (_, _) => const Gap(8),
        itemBuilder: (context, index) {
          final file = controller.attachmentDrafts[index];
          final ext = file.name.split('.').last.toUpperCase();
          final isImage = ['JPG', 'JPEG', 'PNG', 'GIF', 'WEBP'].contains(ext);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56, // Smaller previews
                height: 56,
                decoration: BoxDecoration(
                  color: palette.scaffoldBackground.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: palette.secondaryText.withValues(alpha: 0.1),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: isImage
                      ? Image.file(
                          File(file.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Center(child: Icon(CupertinoIcons.photo)),
                        )
                      : Center(
                          child: Text(
                            ext.length > 4 ? 'FILE' : ext,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: palette.secondaryText,
                            ),
                          ),
                        ),
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () {
                    controller.attachmentDrafts.removeAt(index);
                    onStateChanged();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: palette.scaffoldBackground,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      size: 18,
                      color: palette.secondaryText,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A reusable glassmorphic container for the islands.
class _GlassIsland extends StatelessWidget {
  final AppPalette palette;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const _GlassIsland({
    super.key,
    required this.palette,
    required this.child,
    this.padding,
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Stronger blur
        child: Container(
          padding: padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            // Use glassBackground from palette if available, or tweak manually
            // The user wants it to match app style better.
            // Using a very low alpha surface color usually looks best for glass.
            color: palette.inputBackground.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: palette.text.withValues(alpha: 0.05), // Subtle border
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Helper for the reply/edit preview content layout.
class _PreviewContainer extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final Widget? customLeading;
  final String title;
  final String body;
  final VoidCallback onCancel;

  const _PreviewContainer({
    required this.palette,
    required this.icon,
    this.customLeading,
    required this.title,
    required this.body,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        customLeading ??
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: palette.primary),
            ),
        const Gap(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: palette.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Gap(2),
              Text(
                body,
                style: TextStyle(fontSize: 12, color: palette.secondaryText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onCancel, minimumSize: const Size(32, 32),
          child: Icon(
            CupertinoIcons.xmark_circle_fill,
            size: 18,
            color: palette.secondaryText.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
