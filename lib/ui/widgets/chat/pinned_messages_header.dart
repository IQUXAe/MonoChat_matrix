import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

class PinnedMessagesHeader extends StatefulWidget {
  final Room room;
  final Timeline? timeline;
  final Function(String eventId) onMessageTap;
  final Function(int count)? onCountChanged;

  const PinnedMessagesHeader({
    super.key,
    required this.room,
    this.timeline,
    required this.onMessageTap,
    this.onCountChanged,
  });

  @override
  State<PinnedMessagesHeader> createState() => _PinnedMessagesHeaderState();
}

class _PinnedMessagesHeaderState extends State<PinnedMessagesHeader> {
  List<String> _pinnedEventIds = [];
  int _currentIndex = 0;
  Event? _currentEvent;
  bool _isLoading = false;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _updatePinnedEvents();
    _subscription = widget.room.client.onSync.stream.listen((_) {
      _checkForUpdates();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _checkForUpdates() {
    final stateEvent = widget.room.getState('m.room.pinned_events');
    final newPinned = stateEvent?.content['pinned'];
    if (newPinned is List) {
      final newIds = newPinned.cast<String>();
      if (newIds.length != _pinnedEventIds.length ||
          !newIds.every((id) => _pinnedEventIds.contains(id))) {
        _updatePinnedEvents();
      }
    } else if (_pinnedEventIds.isNotEmpty) {
      if (mounted) {
        setState(() {
          _pinnedEventIds = [];
          _currentEvent = null;
        });
        widget.onCountChanged?.call(0);
      }
    }
  }

  void _updatePinnedEvents() {
    final stateEvent = widget.room.getState('m.room.pinned_events');
    if (stateEvent != null) {
      final content = stateEvent.content;
      final pinned = content['pinned'];
      if (pinned is List) {
        final ids = pinned.map((e) => e.toString()).toList();
        if (mounted) {
          setState(() {
            _pinnedEventIds = ids;
            widget.onCountChanged?.call(_pinnedEventIds.length);
            if (_pinnedEventIds.isNotEmpty) {
              if (_currentIndex >= _pinnedEventIds.length) {
                _currentIndex = _pinnedEventIds.length - 1;
              }
              _currentIndex = _pinnedEventIds.length - 1;
              _loadEvent(_pinnedEventIds[_currentIndex]);
            } else {
              _currentEvent = null;
            }
          });
        }
      }
    }
  }

  Future<void> _loadEvent(String eventId) async {
    if (_currentEvent?.eventId == eventId) return;

    setState(() => _isLoading = true);

    Event? event;
    try {
      final timeline = widget.timeline;
      if (timeline != null) {
        try {
          event = timeline.events.firstWhere((e) => e.eventId == eventId);
        } catch (_) {}
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _currentEvent = event;
        _isLoading = false;
      });
    }
  }

  void _nextMessage() {
    if (_pinnedEventIds.isEmpty) return;
    setState(() {
      _currentIndex--;
      if (_currentIndex < 0) {
        _currentIndex = _pinnedEventIds.length - 1;
      }
    });
    _loadEvent(_pinnedEventIds[_currentIndex]);
  }

  @override
  Widget build(BuildContext context) {
    if (_pinnedEventIds.isEmpty) return const SizedBox.shrink();

    final palette = context.watch<ThemeController>().palette;

    return GestureDetector(
      onTap: () {
        if (_currentEvent != null) {
          widget.onMessageTap(_currentEvent!.eventId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: palette.scaffoldBackground.withOpacity(0.95),
          border: Border(
            bottom: BorderSide(
              color: palette.separator.withOpacity(0.15),
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: palette.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                CupertinoIcons.pin_fill,
                size: 14,
                color: palette.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1.0,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  key: ValueKey(_currentEvent?.eventId ?? 'loading'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.pinnedMessage,
                      style: TextStyle(
                        color: palette.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isLoading
                          ? 'Loading...'
                          : _currentEvent != null
                          ? _currentEvent!.body.replaceAll('\n', ' ')
                          : AppLocalizations.of(context)!.messageNotFound,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.text.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_pinnedEventIds.length > 1)
              GestureDetector(
                onTap: _nextMessage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.transparent, // Hit test
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.secondarySystemBackground
                              .resolveFrom(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_currentIndex + 1}/${_pinnedEventIds.length}',
                          style: TextStyle(
                            fontSize: 10,
                            color: palette.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        CupertinoIcons.chevron_down,
                        size: 14,
                        color: palette.secondaryText,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
