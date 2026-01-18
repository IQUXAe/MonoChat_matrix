import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, DateUtils;
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import 'package:monochat/controllers/chat_controller.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/data/repositories/matrix_chat_repository.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/services/matrix_service.dart';
import 'package:monochat/ui/dialogs/send_file_dialog.dart';
import 'package:monochat/ui/widgets/chat/chat_app_bar.dart';
import 'package:monochat/ui/widgets/chat/date_header.dart';
import 'package:monochat/ui/widgets/chat/message_bubble.dart';
import 'package:monochat/ui/widgets/fallback_file_picker.dart';
import 'package:monochat/ui/widgets/chat/emoji_picker/reaction_picker_sheet.dart';
import 'package:monochat/utils/extensions/stream_extension.dart';

class ChatScreen extends StatefulWidget {
  final Room room;

  const ChatScreen({super.key, required this.room});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static final Logger _log = Logger('ChatScreen');
  final _textController = TextEditingController();
  final AutoScrollController _scrollController = AutoScrollController();
  final ImagePicker _picker = ImagePicker();

  late final ChatController _controller;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    // Create controller in initState for proper lifecycle management
    final matrixService = context.read<MatrixService>();
    final chatRepository = MatrixChatRepository(matrixService);
    _controller = ChatController(
      room: widget.room,
      chatRepository: chatRepository,
    );
  }

  @override
  void deactivate() {
    // Mark as read when screen is being removed from the tree
    // This happens before dispose and gives us a chance to start the operation
    if (!_isExiting) {
      _isExiting = true;
      // Use controller's forceSetReadMarker which uses Timeline like FluffyChat
      _controller.forceSetReadMarker();
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Handle back navigation with read receipt guarantee
  Future<void> _handleExit() async {
    if (_isExiting) return;
    _isExiting = true;

    // Mark as read BEFORE navigating away using Timeline like FluffyChat
    await _controller.forceSetReadMarker();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await _handleExit();
        }
      },
      child: ChangeNotifierProvider.value(
        value: _controller,
        child: Consumer<ChatController>(
          builder: (context, controller, child) {
            final client = controller.client;
            final isInvite = widget.room.membership == Membership.invite;

            return DropTarget(
              onDragDone: (details) => controller.handleDrop(details.files),
              onDragEntered: (_) => controller.setDragging(true),
              onDragExited: (_) => controller.setDragging(false),
              child: Stack(
                children: [
                  CupertinoPageScaffold(
                    resizeToAvoidBottomInset: true,
                    // Remove SafeArea to allow content behind bars
                    child: Stack(
                      children: [
                        // 1. Content Layer (Message List + Input)
                        Column(
                          children: [
                            Expanded(
                              child: isInvite
                                  ? _buildInviteView(context)
                                  : _buildMessageList(context, controller),
                            ),
                            if (!isInvite) _buildTypingIndicator(context),
                            if (!isInvite) _buildInputArea(context, controller),
                          ],
                        ),

                        // 2. Translucent Header Layer
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: ChatAppBar(room: widget.room, client: client),
                        ),
                      ],
                    ),
                  ),
                  if (controller.isDragging)
                    Container(
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.cloud_upload_fill,
                              size: 64,
                              color: Colors.white,
                            ),
                            Gap(16),
                            Text(
                              'Drop files here',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context) {
    return StreamBuilder(
      stream: widget.room.client.onSync.stream,
      builder: (context, snapshot) {
        final typingUsers = widget.room.typingUsers
            .where((u) => u.id != widget.room.client.userID)
            .toList();

        if (typingUsers.isEmpty) return const SizedBox.shrink();

        final names = typingUsers.map((u) => u.calcDisplayname()).join(', ');
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          alignment: Alignment.centerLeft,
          child: Text(
            AppLocalizations.of(context)!.typingIndicator(names),
            style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: CupertinoColors.systemGrey,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInviteView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.envelope_open_fill,
              size: 64,
              color: CupertinoColors.systemGrey,
            ),
            const Gap(16),
            Text(
              AppLocalizations.of(
                context,
              )!.youHaveBeenInvited(widget.room.getLocalizedDisplayname()),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const Gap(32),
            CupertinoButton.filled(
              onPressed: () async {
                await widget.room.join();
                setState(() {});
              },
              child: Text(AppLocalizations.of(context)!.joinRoom),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(BuildContext context, ChatController controller) {
    // Wait for controller's timeline to load
    return FutureBuilder<void>(
      future: controller.loadTimelineFuture,
      builder: (context, snapshot) {
        final timeline = controller.timeline;
        if (timeline == null) {
          return const Center(child: CupertinoActivityIndicator());
        }

        // Use rate-limited stream for better performance
        final roomStream = widget.room.client.onRoomState.stream
            .where((update) => update.roomId == widget.room.id)
            .rateLimit(const Duration(milliseconds: 500));

        return StreamBuilder(
          stream: roomStream,
          builder: (context, snapshot) {
            // Trigger read receipt on updates
            if (snapshot.hasData) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                controller.setReadMarker();
              });
            }

            final events = timeline.events;

            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollUpdateNotification) {
                  // Use tolerance to account for bounce physics and
                  // small scroll offsets when new messages arrive
                  // In reversed list: pixels = 0 means at bottom (newest)
                  const scrollThreshold = 100.0;
                  final scrolledUp =
                      notification.metrics.pixels > scrollThreshold;
                  controller.setScrolledUp(scrolledUp);
                }
                return false;
              },
              child: ListView.custom(
                key: PageStorageKey<String>('chat_${widget.room.id}'),
                controller: _scrollController,
                reverse: true,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                cacheExtent: 350.0,
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  bottom: 8,
                  top: MediaQuery.of(context).padding.top + 60 + 8,
                ),
                childrenDelegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final event = events[index];

                    final isVisible =
                        event.type == EventTypes.Message ||
                        event.type == EventTypes.Sticker ||
                        event.type == EventTypes.Encrypted ||
                        event.type == EventTypes.RoomMember ||
                        event.type == EventTypes.RoomName ||
                        event.type == EventTypes.RoomTopic ||
                        event.type == EventTypes.RoomCreate ||
                        event.type == 'm.room.encryption' ||
                        event.type == 'm.key.verification.request';

                    if (!isVisible) {
                      return const SizedBox.shrink();
                    }

                    final isMe = event.senderId == controller.client.userID;
                    final nextEvent = index > 0 ? events[index - 1] : null;
                    final prevEvent = index < events.length - 1
                        ? events[index + 1]
                        : null;

                    final showTail =
                        nextEvent == null ||
                        nextEvent.senderId != event.senderId;
                    final showDateHeader =
                        prevEvent == null ||
                        !DateUtils.isSameDay(
                          event.originServerTs,
                          prevEvent.originServerTs,
                        );

                    final isFirstInGroup =
                        prevEvent == null ||
                        prevEvent.senderId != event.senderId;

                    return _MessageListItem(
                      key: ValueKey(event.eventId),
                      event: event,
                      isMe: isMe,
                      showTail: showTail,
                      isFirstInGroup: isFirstInGroup,
                      showDateHeader: showDateHeader,
                      client: controller.client,
                      scrollController: _scrollController,
                      index: index,
                      onSwipeReply: () => controller.setReplyTo(event),
                      timeline: timeline,
                    );
                  },
                  childCount: events.length,
                  findChildIndexCallback: (Key key) {
                    if (key is ValueKey<String>) {
                      final eventId = key.value;
                      final index = events.indexWhere(
                        (e) => e.eventId == eventId,
                      );
                      return index >= 0 ? index : null;
                    }
                    return null;
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAttachmentMenu(BuildContext context, ChatController controller) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: <CupertinoActionSheetAction>[
          if (Platform.isIOS || Platform.isAndroid)
            CupertinoActionSheetAction(
              child: Text(AppLocalizations.of(context)!.takePhoto),
              onPressed: () {
                Navigator.pop(context);
                _pickImage(controller, ImageSource.camera);
              },
            ),
          CupertinoActionSheetAction(
            child: Text(AppLocalizations.of(context)!.choosePhoto),
            onPressed: () {
              Navigator.pop(context);
              _pickImage(controller, ImageSource.gallery);
            },
          ),
          CupertinoActionSheetAction(
            child: Text(AppLocalizations.of(context)!.chooseVideo),
            onPressed: () {
              Navigator.pop(context);
              _pickVideo(controller);
            },
          ),
          CupertinoActionSheetAction(
            child: Text(AppLocalizations.of(context)!.chooseFile),
            onPressed: () {
              Navigator.pop(context);
              _pickFile(controller);
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
      ),
    );
  }

  void _handlePickError(Object e) {
    _log.severe('Picker failed', e);
    if (mounted) {
      showCupertinoDialog(
        context: context,
        builder: (c) => CupertinoAlertDialog(
          title: const Text('System Error'),
          content: Text(AppLocalizations.of(context)!.filePickerError),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(c),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _pickImage(ChatController controller, ImageSource source) async {
    try {
      final List<XFile> files = [];
      if (source == ImageSource.camera) {
        final XFile? image = await _picker.pickImage(
          source: source,
          imageQuality: 70,
          maxWidth: 1920,
          maxHeight: 1920,
        );
        if (image != null) files.add(image);
      } else {
        files.addAll(
          await _picker.pickMultiImage(
            imageQuality: 70,
            maxWidth: 1920,
            maxHeight: 1920,
          ),
        );
      }

      if (files.isEmpty) return;

      // Show send dialog
      await SendFileDialog.show(
        context,
        room: widget.room,
        files: files,
        onSend: (files, compress) =>
            controller.sendFiles(files, compress: compress),
      );
    } catch (e) {
      _handlePickError(e);
    }
  }

  Future<void> _pickVideo(ChatController controller) async {
    try {
      final List<XFile> files = await _picker.pickMultipleMedia();
      if (files.isEmpty) return;

      // Show send dialog
      await SendFileDialog.show(
        context,
        room: widget.room,
        files: files,
        onSend: (files, compress) =>
            controller.sendFiles(files, compress: compress),
      );
    } catch (e) {
      _handlePickError(e);
    }
  }

  Future<void> _pickFile(ChatController controller) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select a file',
        lockParentWindow: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;

      final files = result.files
          .where((f) => f.path != null)
          .map((f) => XFile(f.path!, name: f.name))
          .toList();

      if (files.isEmpty) return;

      // Show send dialog
      await SendFileDialog.show(
        context,
        room: widget.room,
        files: files,
        onSend: (files, compress) =>
            controller.sendFiles(files, compress: compress),
      );
    } catch (e) {
      _log.warning('FilePicker failed, trying fallback', e);
      _showFallbackFilePicker(controller);
    }
  }

  void _showFallbackFilePicker(ChatController controller) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => FallbackFilePicker(
        onFileSelected: (file) async {
          // XFile can accept generic file path.
          controller.attachFile(XFile(file.path));
        },
      ),
    );
  }

  // --- UI Components for Input ---

  Widget _buildDraftAttachmentList(ChatController controller) {
    if (controller.attachmentDrafts.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      color: context.watch<ThemeController>().palette.inputBackground,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        scrollDirection: Axis.horizontal,
        itemCount: controller.attachmentDrafts.length,
        separatorBuilder: (_, __) => const Gap(12),
        itemBuilder: (context, index) {
          final file = controller.attachmentDrafts[index];
          final ext = file.name.split('.').last.toUpperCase();
          final isImage = ['JPG', 'JPEG', 'PNG', 'GIF', 'WEBP'].contains(ext);

          return Container(
            width: 200,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.systemGrey4.withOpacity(0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Image preview with proper caching
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 48,
                    height: 48,
                    color: CupertinoColors.systemGrey6,
                    child: isImage
                        ? Image.file(
                            File(file.path),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            // Limit decoded size to 96px (2x for retina)
                            cacheWidth: 96,
                            cacheHeight: 96,
                            errorBuilder: (_, __, ___) => const Icon(
                              CupertinoIcons.photo,
                              size: 24,
                              color: CupertinoColors.systemGrey,
                            ),
                          )
                        : Center(
                            child: Text(
                              ext.length > 4 ? 'FILE' : ext,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ),
                  ),
                ),
                const Gap(8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(2),
                      FutureBuilder<int>(
                        future: file.length(),
                        builder: (context, snapshot) {
                          final size = snapshot.data ?? 0;
                          String sizeStr = '...';
                          if (size > 0) {
                            if (size < 1024)
                              sizeStr = '$size B';
                            else if (size < 1024 * 1024)
                              sizeStr =
                                  '${(size / 1024).toStringAsFixed(1)} KB';
                            else
                              sizeStr =
                                  '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
                          }
                          return Text(
                            sizeStr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: CupertinoColors.systemGrey,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 24,
                  onPressed: () => controller.removeAttachment(file),
                  child: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    size: 20,
                    color: CupertinoColors.systemGrey3,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context, ChatController controller) {
    if (controller.replyingTo == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: context.watch<ThemeController>().palette.inputBackground,
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.reply,
            size: 20,
            color: CupertinoColors.systemGrey,
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.replyingTo(
                    controller.replyingTo?.senderFromMemoryOrFallback
                            .calcDisplayname() ??
                        "User",
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: context.watch<ThemeController>().palette.primary,
                  ),
                ),
                Text(
                  controller.replyingTo?.body ?? 'Attachment',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: () => controller.setReplyTo(null),
            child: const Icon(
              CupertinoIcons.xmark_circle_fill,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, ChatController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.processingFiles.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: context.watch<ThemeController>().palette.inputBackground,
            child: Row(
              children: [
                const CupertinoActivityIndicator(radius: 8),
                const Gap(12),
                Expanded(
                  child: Text(
                    "Uploading ${controller.processingFiles.join(', ')}...",
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        if (controller.replyingTo != null)
          _buildReplyPreview(context, controller),
        _buildDraftAttachmentList(controller), // Added draft list
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: context.watch<ThemeController>().palette.barBackground,
            border: Border(
              top: BorderSide(
                color: context.watch<ThemeController>().palette.separator,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  onPressed: () => _showAttachmentMenu(context, controller),
                  child: const Icon(
                    CupertinoIcons.add,
                    size: 28,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  onPressed: () {
                    showCupertinoModalPopup(
                      context: context,
                      builder: (context) => ReactionPickerSheet(
                        onEmojiSelected: (emoji) {
                          Navigator.pop(context);
                          _textController.text += emoji;
                          controller.updateTyping(true);
                        },
                      ),
                    );
                  },
                  child: const Icon(
                    CupertinoIcons.smiley,
                    size: 26,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                Expanded(
                  child: CupertinoTextField(
                    controller: _textController,
                    placeholder: AppLocalizations.of(
                      context,
                    )!.messagePlaceholder,
                    minLines: 1,
                    maxLines: 5,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context
                          .watch<ThemeController>()
                          .palette
                          .inputBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onChanged: (text) {
                      controller.updateTyping(text.isNotEmpty);
                      // We trigger rebuild to update Send button state potentially,
                      // but TextField handles its own state.
                      // setState not strictly needed if we don't change button color reactively.
                    },
                    suffix: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        controller.sendMessage(_textController.text);
                        _textController.clear();
                      },
                      child: Icon(
                        CupertinoIcons.arrow_up_circle_fill,
                        size: 32,
                        color: context.watch<ThemeController>().palette.primary,
                      ),
                    ),
                    onSubmitted: (text) {
                      controller.sendMessage(text);
                      _textController.clear();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Optimized message list item widget.
///
/// This is a separate StatefulWidget to:
/// 1. Prevent unnecessary rebuilds when the list updates
/// 2. Only animate on first appearance, not on every sync
/// 3. Preserve widget state across list rebuilds
class _MessageListItem extends StatefulWidget {
  final Event event;
  final bool isMe;
  final bool showTail;
  final bool isFirstInGroup;
  final bool showDateHeader;
  final Client client;
  final AutoScrollController scrollController;
  final int index;
  final VoidCallback onSwipeReply;

  const _MessageListItem({
    super.key,
    required this.event,
    required this.isMe,
    required this.showTail,
    required this.isFirstInGroup,
    required this.showDateHeader,
    required this.client,
    required this.scrollController,
    required this.index,
    required this.onSwipeReply,
    required this.timeline,
  });

  final Timeline timeline;

  @override
  State<_MessageListItem> createState() => _MessageListItemState();
}

class _MessageListItemState extends State<_MessageListItem>
    with SingleTickerProviderStateMixin {
  // Global set to track which messages have been animated
  // Uses transactionId for local echo, eventId for delivered messages
  static final Set<String> _animatedMessages = {};

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  /// Get stable ID that doesn't change when local echo becomes delivered
  String get _stableMessageId {
    // For local echo messages, use unsigned.transaction_id if available
    final transactionId = widget.event.unsigned?['transaction_id'] as String?;
    if (transactionId != null) return transactionId;

    // For messages with local echo prefix, extract the core ID
    final eventId = widget.event.eventId;
    if (eventId.startsWith('m-')) {
      // Already a local echo ID - use it
      return eventId;
    }

    return eventId;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutQuad,
          ),
        );

    // Check if this message was already animated using stable ID
    final stableId = _stableMessageId;
    if (_animatedMessages.contains(stableId)) {
      // Already animated - show immediately
      _animationController.value = 1.0;
    } else {
      // First time - animate and mark as animated
      _animatedMessages.add(stableId);
      _animationController.forward();

      // Cleanup old entries to prevent memory leak (keep last 500)
      if (_animatedMessages.length > 500) {
        final toRemove = _animatedMessages.take(100).toList();
        _animatedMessages.removeAll(toRemove);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AutoScrollTag(
      key: ValueKey(widget.event.eventId),
      controller: widget.scrollController,
      index: widget.index,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Dismissible(
            key: ValueKey('swipe_${widget.event.eventId}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              widget.onSwipeReply();
              return false;
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.transparent,
              child: const Icon(
                CupertinoIcons.reply,
                color: CupertinoColors.systemGrey,
              ),
            ),
            child: Column(
              children: [
                if (widget.showDateHeader)
                  DateHeader(date: widget.event.originServerTs),
                MessageBubble(
                  key: ValueKey(widget.event.eventId),
                  event: widget.event,
                  isMe: widget.isMe,
                  showTail: widget.showTail,
                  isFirstInGroup: widget.isFirstInGroup,
                  client: widget.client,
                  timeline: widget.timeline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
