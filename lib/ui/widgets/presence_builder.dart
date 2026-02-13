import 'package:flutter/cupertino.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/services/presence_manager.dart';

class PresenceBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, CachedPresence? presence) builder;
  final String userId;
  final Client client;

  const PresenceBuilder({
    super.key,
    required this.builder,
    required this.userId,
    required this.client,
  });

  @override
  State<PresenceBuilder> createState() => _PresenceBuilderState();
}

class _PresenceBuilderState extends State<PresenceBuilder> {
  CachedPresence? _presence;

  void _onPresenceUpdate(CachedPresence presence) {
    if (!mounted) return;
    setState(() {
      _presence = presence;
    });
  }

  @override
  void initState() {
    super.initState();
    // Fetch initial
    widget.client.fetchCurrentPresence(widget.userId).then((p) {
      if (mounted) setState(() => _presence = p);
    });

    // Listen for updates via centralized manager
    PresenceManager().listen(widget.client, widget.userId, _onPresenceUpdate);
  }

  @override
  void didUpdateWidget(PresenceBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.client != widget.client) {
      PresenceManager().unlisten(
        oldWidget.client,
        oldWidget.userId,
        _onPresenceUpdate,
      );
      PresenceManager().listen(widget.client, widget.userId, _onPresenceUpdate);

      // Re-fetch initial
      widget.client.fetchCurrentPresence(widget.userId).then((p) {
        if (mounted) setState(() => _presence = p);
      });
    }
  }

  @override
  void dispose() {
    PresenceManager().unlisten(widget.client, widget.userId, _onPresenceUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _presence);
}
