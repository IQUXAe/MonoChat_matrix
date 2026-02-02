import 'dart:convert';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, DateUtils;
import 'package:flutter/services.dart'; // Added
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; /* Added */
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/chat_controller.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/data/repositories/matrix_chat_repository.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/services/matrix_service.dart';
import 'package:monochat/ui/dialogs/send_file_dialog.dart';
import 'package:monochat/ui/widgets/chat/chat_app_bar.dart';
import 'package:monochat/ui/widgets/chat/date_header.dart';
import 'package:monochat/ui/widgets/chat/floating_input_bar.dart';
import 'package:monochat/ui/widgets/chat/message_bubble.dart';
import 'package:monochat/ui/widgets/chat/message_status_indicator.dart'
    as indicators;
import 'package:monochat/ui/widgets/chat/pinned_messages_header.dart'; // Added
import 'package:monochat/ui/widgets/chat/read_receipts.dart';
import 'package:monochat/ui/widgets/chat/scroll_to_bottom_button.dart';
import 'package:monochat/ui/widgets/chat/system_message_item.dart';
import 'package:monochat/ui/widgets/fallback_file_picker.dart';
import 'package:monochat/utils/extensions/stream_extension.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

class ChatScreen extends StatefulWidget {
  final Room room;

  const ChatScreen({super.key, required this.room});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  static final Logger _log = Logger('ChatScreen');
  final _textController = TextEditingController();
  final AutoScrollController _scrollController = AutoScrollController();
  final ImagePicker _picker = ImagePicker();
  final _storage = const FlutterSecureStorage();

  late final ChatController _controller;
  bool _isExiting = false;
  bool _showScrollButton = false;
  int _pinnedMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreScrollPosition();
    _restoreDraft();
    // Create controller in initState for proper lifecycle management
    final matrixService = context.read<MatrixService>();
    final chatRepository = MatrixChatRepository(matrixService);
    _controller = ChatController(
      room: widget.room,
      chatRepository: chatRepository,
    );

    // Set active room ID for push notification filtering
    matrixService.setActiveRoom(widget.room.id);
  }

  Future<void> _restoreScrollPosition() async {
    try {
      final key = 'chat_scroll_${widget.room.id}';
      final savedPos = await _storage.read(key: key);
      if (savedPos != null) {
        final pixels = double.tryParse(savedPos);
        if (pixels != null && pixels > 0) {
          // If controller attached, jump immediately
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(pixels);
          } else {
            // Otherwise wait for first frame
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(pixels);
              }
            });
          }
        }
      }
    } catch (e) {
      _log.warning('Failed to restore scroll position', e);
    }
  }

  Future<void> _saveScrollPosition() async {
    if (!_scrollController.hasClients) return;
    try {
      final pixels = _scrollController.position.pixels;
      final key = 'chat_scroll_${widget.room.id}';
      if (pixels > 10) {
        await _storage.write(key: key, value: pixels.toString());
      } else {
        // If at bottom, clear it so next open starts fresh at bottom
        await _storage.delete(key: key);
      }
    } catch (e) {
      _log.warning('Failed to save scroll position', e);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final matrixService = MatrixService();

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveScrollPosition();
      _saveDraft();
      // Clear active room when going to background
      matrixService.setActiveRoom(null);
    } else if (state == AppLifecycleState.resumed) {
      // Restore active room when coming back
      matrixService.setActiveRoom(widget.room.id);
    }
  }

  @override
  void deactivate() {
    // Mark as read when screen is being removed from the tree
    // This happens before dispose and gives us a chance to start the operation
    if (!_isExiting) {
      _isExiting = true;
      // Use controller's forceSetReadMarker which uses Timeline
      _controller.forceSetReadMarker();
      _saveScrollPosition();
      _saveDraft();

      // Clear active room
      MatrixService().setActiveRoom(null);
    }
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Handle back navigation with read receipt guarantee
  Future<void> _handleExit() async {
    if (_isExiting) return;
    _isExiting = true;

    // Mark as read BEFORE navigating away using Timeline
    await _controller.forceSetReadMarker();
    await _saveScrollPosition();
    await _saveDraft();
  }

  Future<void> _saveDraft() async {
    try {
      final text = _textController.text;
      final replyId = _controller.replyingTo?.eventId;

      if (text.isEmpty && replyId == null) {
        await _storage.delete(key: 'chat_draft_${widget.room.id}');
        return;
      }

      final draft = {
        'text': text,
        'replyId': replyId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await _storage.write(
        key: 'chat_draft_${widget.room.id}',
        value: jsonEncode(draft),
      );
    } catch (e) {
      _log.warning('Failed to save draft', e);
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final value = await _storage.read(key: 'chat_draft_${widget.room.id}');
      if (value == null) return;

      final draft = jsonDecode(value) as Map<String, dynamic>;
      final text = draft['text'] as String?;
      final replyId = draft['replyId'] as String?;

      if (text != null && text.isNotEmpty) {
        _textController.text = text;
      }

      if (replyId != null) {
        /*
        try {
          // Fetch event to reply
          // final event = await widget.room.client.getEvent(
          //   widget.room.id,
          //   replyId,
          // );
          // if (event != null) {
          //   _controller.setReplyTo(event);
          // }
        } catch (e) {
          _log.warning('Could not restore reply to $replyId', e);
        }
        */
      }
    } catch (e) {
      _log.warning('Failed to restore draft', e);
    }
  }

  Future<void> _togglePin(Event event) async {
    try {
      final pinnedEvent = widget.room.getState('m.room.pinned_events');
      final content = pinnedEvent?.content ?? {};
      List<String> pinnedIds = [];

      final pinnedList = content['pinned'];
      if (pinnedList is List) {
        pinnedIds = pinnedList.map((e) => e.toString()).toList();
      }

      final isPinned = pinnedIds.contains(event.eventId);
      if (isPinned) {
        pinnedIds.remove(event.eventId);
      } else {
        pinnedIds.add(event.eventId);
      }

      await widget.room.client.setRoomStateWithKey(
        widget.room.id,
        'm.room.pinned_events',
        '',
        {'pinned': pinnedIds},
      );
    } catch (e) {
      if (!mounted) return;
      // ... error
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;

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
            final bottomPadding = MediaQuery.of(context).padding.bottom;

            return DropTarget(
              onDragDone: (details) => controller.handleDrop(details.files),
              onDragEntered: (_) => controller.setDragging(true),
              onDragExited: (_) => controller.setDragging(false),
              // Use ColoredBox as base layer instead of CupertinoPageScaffold
              // This eliminates the unwanted background from SafeArea
              child: ColoredBox(
                color: palette.scaffoldBackground,
                child: Stack(
                  children: [
                    // 1. Message list (full screen, with padding for input)
                    Positioned.fill(
                      child: Column(
                        children: [
                          Expanded(
                            child: isInvite
                                ? _buildInviteView(context)
                                : _buildMessageList(context, controller),
                          ),

                          // Bottom space for floating input
                        ],
                      ),
                    ),

                    // 2. Translucent Header
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ChatAppBar(room: widget.room, client: client),
                          PinnedMessagesHeader(
                            room: widget.room,
                            onMessageTap: _scrollToEvent,
                            onCountChanged: (count) {
                              if (_pinnedMessageCount != count) {
                                setState(() => _pinnedMessageCount = count);
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    // 3. Floating Input Bar (truly floating, no background)
                    if (!isInvite)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTypingIndicatorText(context),
                            FloatingInputBar(
                              textController: _textController,
                              controller: controller,
                              palette: palette,
                              bottomPadding:
                                  MediaQuery.of(context).viewInsets.bottom > 0
                                  ? 0
                                  : bottomPadding,
                              onSend: () {
                                controller.sendMessage(_textController.text);
                                _textController.clear();
                                setState(() {});
                              },
                              onAttachment: () =>
                                  _showAttachmentMenu(context, controller),
                              onStateChanged: () => setState(() {}),
                            ),
                          ],
                        ),
                      ),

                    // 5. Scroll to Bottom Button
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      right: 16,
                      bottom:
                          MediaQuery.of(context).viewInsets.bottom +
                          80 +
                          (controller.replyingTo != null ? 50 : 0),
                      child: StreamBuilder(
                        stream: widget.room.client.onSync.stream,
                        builder: (context, _) {
                          return ScrollToBottomButton(
                            visible: _showScrollButton,
                            unreadCount: widget.room.notificationCount,
                            onPressed: () {
                              _scrollController.animateTo(
                                0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            },
                          );
                        },
                      ),
                    ),
                    // 4. Drag overlay
                    if (controller.isDragging)
                      Container(
                        color: Colors.black.withValues(alpha: 0.5),
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
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTypingIndicatorText(BuildContext context) {
    return StreamBuilder(
      stream: widget.room.client.onSync.stream,
      builder: (context, snapshot) {
        final typingUsers = widget.room.typingUsers
            .where((u) => u.id != widget.room.client.userID)
            .toList();

        if (typingUsers.isEmpty) return const SizedBox.shrink();

        final palette = context.read<ThemeController>().palette;
        String text;
        if (typingUsers.length == 1) {
          text = '${typingUsers.first.calcDisplayname()} is typing...';
        } else if (typingUsers.length == 2) {
          text =
              '${typingUsers.first.calcDisplayname()} and ${typingUsers[1].calcDisplayname()} are typing...';
        } else {
          text = '${typingUsers.length} people are typing...';
        }

        return Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Text(
            text,
            style: TextStyle(
              color: palette.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
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

            // FILTER VISIBLE EVENTS HERE
            // Filtering hidden events (like membership changes) significantly improves
            // rendering performance, especially in large groups.
            final visibleEvents = timeline.events.where((event) {
              return (event.type == EventTypes.Message ||
                      event.type == EventTypes.Sticker ||
                      event.type == EventTypes.Encrypted ||
                      event.type == EventTypes.RoomMember ||
                      event.type == EventTypes.RoomName ||
                      event.type == EventTypes.RoomTopic ||
                      event.type == EventTypes.RoomCreate ||
                      event.type == 'm.room.encryption' ||
                      event.type == 'm.key.verification.request' ||
                      event.type.startsWith('m.call.')) &&
                  event.relationshipType != 'm.replace'; // Filter edits
            }).toList();

            // Create index map for O(1) lookup in findChildIndexCallback
            // This prevents O(N) scan per item during layout updates, crucial for large lists
            final eventIdMap = {
              for (var i = 0; i < visibleEvents.length; i++)
                visibleEvents[i].eventId: i,
            };

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
                  if (_showScrollButton != scrolledUp) {
                    setState(() => _showScrollButton = scrolledUp);
                  }

                  // Active Loading / Pagination
                  // Significantly increased threshold (2000px) to load history much earlier
                  // This makes the loading feel "faster" as it happens before the user hits the edge
                  if (notification.metrics.extentAfter < 2000) {
                    controller.timeline?.requestHistory();
                  }
                }

                // Save scroll position when scrolling stops
                if (notification is ScrollEndNotification) {
                  _saveScrollPosition();
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
                // Keep more items in cache for smoother scrolling but not too many for startup speed
                cacheExtent: 600.0,
                padding: EdgeInsets.only(
                  left: 8,
                  right: 8,
                  bottom:
                      8 +
                      50 +
                      MediaQuery.of(context).padding.bottom +
                      MediaQuery.of(context).viewInsets.bottom,
                  top:
                      MediaQuery.of(context).padding.top +
                      60 +
                      8 +
                      (_pinnedMessageCount > 0 ? 56 : 0),
                ),
                semanticChildCount: visibleEvents.length,
                childrenDelegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= visibleEvents.length) return null;
                    final event = visibleEvents[index];

                    final isMe = event.senderId == controller.client.userID;
                    final nextEvent = index > 0
                        ? visibleEvents[index - 1]
                        : null;
                    final prevEvent = index < visibleEvents.length - 1
                        ? visibleEvents[index + 1]
                        : null;

                    final showTail =
                        nextEvent == null ||
                        nextEvent.senderId != event.senderId ||
                        (nextEvent.type ==
                            EventTypes.RoomMember); // Break on system events

                    final showDateHeader =
                        prevEvent == null ||
                        !DateUtils.isSameDay(
                          event.originServerTs,
                          prevEvent.originServerTs,
                        );

                    final isFirstInGroup =
                        prevEvent == null ||
                        prevEvent.senderId != event.senderId ||
                        (prevEvent.type == EventTypes.RoomMember);

                    final pinnedState = widget.room.getState(
                      'm.room.pinned_events',
                    );
                    final pinnedContent = pinnedState?.content['pinned'];
                    final pinnedIds = (pinnedContent is List)
                        ? pinnedContent.cast<String>()
                        : <String>[];
                    final isPinned = pinnedIds.contains(event.eventId);

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
                      onReplyTap: _scrollToEvent,
                      onReply: () => controller.setReplyTo(event),
                      onEdit: () => controller.startEditing(event),
                      onDelete: () => controller.redactEvent(event.eventId),
                      onPin: () => _togglePin(event),
                      isPinned: isPinned,
                    );
                  },
                  childCount: visibleEvents.length,
                  findChildIndexCallback: (key) {
                    if (key is ValueKey<String>) {
                      return eventIdMap[key.value];
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
      builder: (context) => CupertinoActionSheet(
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
      final files = <XFile>[];
      if (source == ImageSource.camera) {
        final image = await _picker.pickImage(
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
      if (!mounted) return;
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
      final files = await _picker.pickMultipleMedia();
      if (files.isEmpty) return;

      // Show send dialog
      if (!mounted) return;
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
      if (!mounted) return;
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

  void _scrollToEvent(String eventId) {
    // Find index of event in visible list
    // Note: We need access to the current list of events.
    // Ideally we can search the timeline.
    final timeline = _controller.timeline;
    if (timeline == null) return;

    final index = timeline.events.indexWhere((e) => e.eventId == eventId);
    if (index != -1) {
      _scrollController.scrollToIndex(
        index,
        preferPosition: AutoScrollPosition.middle,
      );
      // Flash highlight? (Optional polish)
    } else {
      // Try to load history if not found?
      // For now, simpler feedback
      HapticFeedback.mediumImpact();
    }
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
  final Function(String) onReplyTap;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
    required this.onReplyTap,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.timeline,
    this.onPin,
    this.isPinned = false,
  });

  final VoidCallback? onPin;
  final bool isPinned;

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
    final isSystemMessage =
        widget.event.type == EventTypes.RoomMember ||
        widget.event.type == EventTypes.RoomName ||
        widget.event.type == EventTypes.RoomTopic ||
        widget.event.type == EventTypes.RoomCreate ||
        widget.event.type == 'm.room.encryption' ||
        widget.event.type.startsWith('m.call.');

    if (isSystemMessage) {
      return AutoScrollTag(
        key: ValueKey(widget.event.eventId),
        controller: widget.scrollController,
        index: widget.index,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              if (widget.showDateHeader)
                DateHeader(date: widget.event.originServerTs),
              SystemMessageItem(event: widget.event),
            ],
          ),
        ),
      );
    }

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
                  onReplyTap: widget.onReplyTap,
                  onReply: widget.onReply,
                  onEdit: widget.onEdit,
                  onDelete: widget.onDelete,
                  onPin: widget.onPin,
                  isPinned: widget.isPinned,
                ),
                Builder(
                  builder: (context) {
                    // Safe extraction logic (duplicated from ReadReceipts widget for consistenct check)
                    var hasReceipts = false;
                    try {
                      // Helper to safely extract ID
                      String? extractId(dynamic r) {
                        if (r == null) return null;
                        try {
                          return r.userId;
                        } catch (_) {}
                        try {
                          return r.senderId;
                        } catch (_) {}
                        try {
                          return r.uId;
                        } catch (_) {}
                        try {
                          return r.user?.id;
                        } catch (_) {}
                        try {
                          final json = r.toJson();
                          if (json is Map) {
                            return json['userId'] ??
                                json['senderId'] ??
                                json['user_id'];
                          }
                        } catch (_) {}
                        return null;
                      }

                      hasReceipts = widget.event.receipts.any((r) {
                        final id = extractId(r);
                        return id != null && id != widget.client.userID;
                      });
                    } catch (_) {
                      hasReceipts = false;
                    }

                    if (!widget.showTail && !hasReceipts) {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: EdgeInsets.only(
                        top: 2,
                        right: widget.isMe ? 12 : 60,
                        left: widget.isMe ? 60 : 12,
                      ),
                      child: Row(
                        mainAxisAlignment: widget.isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          if (hasReceipts && widget.index == 0)
                            ReadReceipts(
                              event: widget.event,
                              client: widget.client,
                            ),
                          // Only show status indicator if NO receipts and it's my message
                          // AND it is the very last message in the timeline (index 0)
                          if (widget.isMe &&
                              widget.index == 0 &&
                              !hasReceipts) ...[
                            const Gap(4),
                            indicators.MessageStatusIndicator(
                              event: widget.event,
                              isMe: widget.isMe,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
