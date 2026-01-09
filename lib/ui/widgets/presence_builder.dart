import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:matrix/matrix.dart';

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
  StreamSubscription<CachedPresence>? _sub;

  void _updatePresence(CachedPresence? presence) {
    if (!mounted) return;
    setState(() {
      _presence = presence;
    });
  }

  @override
  void initState() {
    super.initState();
    // Fetch initial
    widget.client.fetchCurrentPresence(widget.userId).then(_updatePresence);

    // Listen for updates
    _sub = widget.client.onPresenceChanged.stream
        .where((presence) => presence.userid == widget.userId)
        .listen(_updatePresence);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _presence);
}
