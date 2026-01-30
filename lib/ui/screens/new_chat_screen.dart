import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:gap/gap.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/controllers/room_list_controller.dart';
import 'package:monochat/controllers/space_controller.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/ui/screens/chat_screen.dart';
import 'package:monochat/ui/screens/create_group_screen.dart';
import 'package:monochat/ui/screens/create_space_screen.dart';
import 'package:monochat/ui/widgets/matrix_avatar.dart';
import 'package:provider/provider.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _searchController = TextEditingController();
  final _tagController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  String? _error;
  List<Profile> _searchResults = [];
  List<PublishedRoomsChunk> _publicRooms = [];

  @override
  void dispose() {
    _searchController.dispose();
    _tagController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _publicRooms = [];
        _error = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.contains(':')) {
        _performSearch(query);
      } else if (query.length >= 3) {
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final roomController = context.read<RoomListController>();

      // Smart Search Logic
      Future<List<Profile>>? usersFuture;
      Future<List<PublishedRoomsChunk>>? roomsFuture;

      if (query.startsWith('@')) {
        // User explicitly searching for a user
        usersFuture = roomController.searchUsers(query);
      } else if (query.startsWith('#')) {
        // User explicitly searching for a room
        String? targetServer;
        // Try to extract server from alias
        if (query.contains(':')) {
          final parts = query.split(':');
          if (parts.length > 1 && parts[1].isNotEmpty) {
            targetServer = parts[1];
          }
        }
        roomsFuture = roomController.searchPublicRooms(
          query,
          server: targetServer,
        );
      } else {
        // Ambiguous - search both
        usersFuture = roomController.searchUsers(query);
        roomsFuture = roomController.searchPublicRooms(query);
      }

      final results = await Future.wait([
        usersFuture ?? Future.value(<Profile>[]),
        roomsFuture ?? Future.value(<PublishedRoomsChunk>[]),
      ]);

      final users = results[0] as List<Profile>;
      final rooms = results[1] as List<PublishedRoomsChunk>;

      if (mounted) {
        setState(() {
          _searchResults = users;
          _publicRooms = rooms;
          _isLoading = false;
          _error = (users.isEmpty && rooms.isEmpty) ? 'No results found' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _joinRoom(String roomIdOrAlias) async {
    setState(() => _isLoading = true);
    try {
      final authController = context.read<AuthController>();
      final client = authController.client;
      if (client == null) return;

      var query = roomIdOrAlias.trim();
      // Auto-prepend # if it looks like an alias but missing #
      if (!query.startsWith('#') &&
          !query.startsWith('!') &&
          query.contains(':')) {
        query = '#$query';
      }

      // Check if already joined
      var room = client.getRoomById(query);

      if (room == null) {
        // Try to join
        final newRoomId = await client.joinRoom(query);
        // Wait for the room to appear in the client
        // Simple retry mechanism to wait for the room to be available
        for (var i = 0; i < 10; i++) {
          room = client.getRoomById(newRoomId);
          if (room != null) break;
          await Future.delayed(const Duration(milliseconds: 200));
        }
            }

      if (mounted) {
        if (room != null) {
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(builder: (_) => ChatScreen(room: room!)),
          );
        } else {
          setState(() {
            _error =
                'Joined room, but could not load content immediately. Check your chat list.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to join room: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createChat(String mxid) async {
    // Check if it's a room ID / alias by simplistic check, though user ID also has colon.
    // Assuming createChat is for users (direct chat).
    setState(() => _isLoading = true);
    try {
      final roomController = context.read<RoomListController>();
      final roomId = await roomController.createDirectChat(mxid);

      if (mounted && roomId != null) {
        final authController = context.read<AuthController>();
        final room = authController.client?.getRoomById(roomId);

        if (room != null) {
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(builder: (_) => ChatScreen(room: room)),
          );
        } else {
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Could not create chat';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to create chat: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showJoinByTagDialog() {
    _tagController.clear();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(AppLocalizations.of(context)!.joinByTag),
        content: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: CupertinoTextField(
            controller: _tagController,
            placeholder: AppLocalizations.of(context)!.enterTag,
            autofocus: true,
            style: TextStyle(color: CupertinoTheme.of(context).primaryColor),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          CupertinoDialogAction(
            onPressed: () {
              final tag = _tagController.text.trim();
              if (tag.isNotEmpty) {
                Navigator.pop(ctx);
                _joinRoom(tag);
              }
            },
            child: Text(AppLocalizations.of(context)!.join),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;
    final client = context.read<AuthController>().client;
    final l10n = AppLocalizations.of(context)!;
    final spaceController = context.read<SpaceController>();

    return CupertinoPageScaffold(
      backgroundColor: palette.scaffoldBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: palette.barBackground,
        middle: Text(l10n.newChat),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Text(l10n.cancel),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CupertinoTextField(
                controller: _searchController,
                placeholder: l10n.searchUsers,
                autofocus: true,
                padding: const EdgeInsets.all(12),
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(
                    CupertinoIcons.search,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                decoration: BoxDecoration(
                  color: palette.inputBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (text) {
                  if (text.startsWith('@') &&
                      text.contains(':') &&
                      _searchResults.isEmpty) {
                    _createChat(text);
                  } else if (text.startsWith('#') &&
                      text.contains(':') &&
                      _publicRooms.isEmpty) {
                    _joinRoom(text);
                  } else {
                    _performSearch(text);
                  }
                },
              ),
            ),

            // Action Items (Create Group, Space, Join) - Only if search is empty
            if (_searchController.text.isEmpty)
              Expanded(
                child: ListView(
                  children: [
                    _ActionItem(
                      icon: CupertinoIcons.person_3_fill,
                      title: l10n.newGroup,
                      subtitle: l10n
                          .createGroupDescription, // Reuse string or generic desc
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => const CreateGroupScreen(),
                          ),
                        );
                      },
                      palette: palette,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 60),
                      child: Container(color: palette.separator, height: 0.5),
                    ),
                    _ActionItem(
                      icon: CupertinoIcons.folder_fill,
                      title: l10n.newSpace,
                      subtitle: l10n.spaceDescription,
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: spaceController,
                              child: const CreateSpaceScreen(),
                            ),
                          ),
                        );
                      },
                      palette: palette,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 60),
                      child: Container(color: palette.separator, height: 0.5),
                    ),
                    _ActionItem(
                      icon: CupertinoIcons.tag_fill,
                      title: l10n.joinByTag,
                      subtitle: l10n.enterTag,
                      onTap: _showJoinByTagDialog,
                      palette: palette,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 60),
                      child: Container(color: palette.separator, height: 0.5),
                    ),
                  ],
                ),
              ),

            // Search Loading
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: CupertinoActivityIndicator(),
              ),

            // Search Error
            if (_error != null &&
                !_isLoading &&
                _searchController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _error!,
                  style: const TextStyle(color: CupertinoColors.systemGrey),
                ),
              ),

            // Search Results
            if (_searchController.text.isNotEmpty)
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // User Search Results
                    if (_searchResults.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'USERS',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.secondaryText,
                            ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final profile = _searchResults[index];
                          if (client == null) return const SizedBox();

                          return GestureDetector(
                            onTap: () => _createChat(profile.userId),
                            child: Container(
                              color: palette.scaffoldBackground,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  MatrixAvatar(
                                    avatarUrl: profile.avatarUrl,
                                    name: profile.displayName ?? profile.userId,
                                    client: client,
                                    size: 44,
                                    userId: profile.userId,
                                  ),
                                  const Gap(12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile.displayName ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: palette.text,
                                          ),
                                        ),
                                        Text(
                                          profile.userId,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: palette.secondaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }, childCount: _searchResults.length),
                      ),
                    ],

                    // Public Rooms Results
                    if (_publicRooms.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Text(
                            'PUBLIC ROOMS',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.secondaryText,
                            ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final room = _publicRooms[index];
                          if (client == null) return const SizedBox();
                          // Construct a fake room or use room chunk data
                          final alias = room.canonicalAlias ?? room.roomId;

                          return GestureDetector(
                            onTap: () => _joinRoom(room.roomId),
                            child: Container(
                              color: palette.scaffoldBackground,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  MatrixAvatar(
                                    avatarUrl: room.avatarUrl,
                                    name: room.name ?? alias,
                                    client: client,
                                    size: 44,
                                    userId: room.roomId,
                                  ),
                                  const Gap(12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          room.name ?? 'Unknown Room',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: palette.text,
                                          ),
                                        ),
                                        if (room.topic != null)
                                          Text(
                                            room.topic!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: palette.secondaryText,
                                            ),
                                          )
                                        else
                                          Text(
                                            alias,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: palette.secondaryText,
                                            ),
                                          ),
                                        Text(
                                          '${room.numJoinedMembers} members',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: palette.secondaryText
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }, childCount: _publicRooms.length),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final dynamic palette;

  const _ActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        color: palette.scaffoldBackground,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: palette.primary, size: 24),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: palette.secondaryText,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_forward,
              color: palette.secondaryText.withValues(alpha: 0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
