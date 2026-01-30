import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider;
import 'package:gap/gap.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/ui/dialogs/user_profile_dialog.dart';
import 'package:monochat/ui/widgets/matrix_avatar.dart';
import 'package:provider/provider.dart';

import '../theme/app_palette.dart';

class RoomMembersScreen extends StatefulWidget {
  final Room room;
  final Client client;

  const RoomMembersScreen({
    super.key,
    required this.room,
    required this.client,
  });

  @override
  State<RoomMembersScreen> createState() => _RoomMembersScreenState();
}

class _RoomMembersScreenState extends State<RoomMembersScreen> {
  List<User>? _members;
  List<User>? _filteredMembers;
  bool _isLoading = true;
  String? _error;
  final _searchController = TextEditingController();

  StreamSubscription? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _initLoading();
    // Listen for sync updates to avoid lag from individual event streams
    _syncSubscription = widget.client.onSync.stream
        .where((s) {
          return s.rooms?.join?[widget.room.id]?.timeline?.events?.any(
                (e) => e.type == EventTypes.RoomMember,
              ) ??
              false;
        })
        .listen((_) => _updateMembers());
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (_members == null) return;

    setState(() {
      if (query.isEmpty) {
        _filteredMembers = List.from(_members!);
      } else {
        _filteredMembers = _members!.where((user) {
          final name = user.displayName?.toLowerCase() ?? '';
          final id = user.id.toLowerCase();
          return name.contains(query) || id.contains(query);
        }).toList();
      }
    });
  }

  void _updateMembers([List<User>? specificMembers]) {
    if (!mounted) return;
    final members = specificMembers ?? widget.room.getParticipants();
    if (members.isNotEmpty) {
      setState(() {
        _members = members
          ..sort((a, b) => b.powerLevel.compareTo(a.powerLevel));
        _isLoading = false;
      });
      _onSearchChanged();
    }
  }

  Future<void> _initLoading() async {
    // 1. Show existing cache immediately
    final cached = widget.room.getParticipants();
    if (cached.isNotEmpty) {
      _updateMembers(cached);
    } else {
      _updateMembers();
    }

    // 2. Request fresh list in background
    try {
      final fetched = await widget.room.requestParticipants(
        [...Membership.values]..remove(Membership.leave),
      );
      if (mounted) {
        _updateMembers(fetched);
      }
    } catch (e) {
      if (mounted && (_members == null || _members!.isEmpty)) {
        setState(() {
          _error = 'Failed to load members: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;

    return CupertinoPageScaffold(
      backgroundColor: palette.scaffoldBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: palette.barBackground,
        middle: Text('Members', style: TextStyle(color: palette.text)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: 'Search participants',
                style: TextStyle(color: palette.text),
                placeholderStyle: TextStyle(
                  color: palette.secondaryText.withValues(alpha: 0.7),
                ),
              ),
            ),
            Expanded(child: _buildContent(palette)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppPalette palette) {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: TextStyle(color: palette.secondaryText),
              textAlign: TextAlign.center,
            ),
            const Gap(16),
            CupertinoButton(
              child: const Text('Retry'),
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _initLoading();
              },
            ),
          ],
        ),
      );
    }

    if (_filteredMembers == null || _filteredMembers!.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isNotEmpty ? 'No members found' : 'No members',
          style: TextStyle(color: palette.secondaryText),
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredMembers!.length,
      itemBuilder: (context, index) {
        final member = _filteredMembers![index];
        final isAdmin = member.powerLevel >= 100;
        final isModerator = member.powerLevel >= 50 && member.powerLevel < 100;

        return Column(
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                UserProfileDialog.show(
                  context: context,
                  profile: Profile(
                    userId: member.id,
                    displayName: member.displayName,
                    avatarUrl: member.avatarUrl,
                  ),
                  client: widget.client,
                  room: widget.room,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    MatrixAvatar(
                      avatarUrl: member.avatarUrl,
                      name: member.calcDisplayname(),
                      client: widget.client,
                      size: 40,
                      userId: member.id,
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.calcDisplayname(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: palette.text,
                            ),
                          ),
                          Text(
                            member.id,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isAdmin || isModerator)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? CupertinoColors.systemRed.withValues(alpha: 0.1)
                              : CupertinoColors.systemOrange.withValues(
                                  alpha: 0.1,
                                ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isAdmin ? 'Admin' : 'Mod',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isAdmin
                                ? CupertinoColors.systemRed
                                : CupertinoColors.systemOrange,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 68),
              child: Divider(
                height: 1,
                color: palette.separator.withValues(alpha: 0.3),
              ),
            ),
          ],
        );
      },
    );
  }
}
