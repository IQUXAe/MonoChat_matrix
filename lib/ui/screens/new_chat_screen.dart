import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:gap/gap.dart';
import 'package:matrix/matrix.dart';
import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/controllers/room_list_controller.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/ui/screens/chat_screen.dart';
import 'package:monochat/ui/widgets/matrix_avatar.dart';
import 'package:provider/provider.dart';
import 'package:monochat/ui/screens/create_group_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  String? _error;
  List<Profile> _searchResults = [];
  List<PublicRoomsChunk> _publicRooms = [];

  @override
  void dispose() {
    _searchController.dispose();
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
      Future<List<PublicRoomsChunk>>? roomsFuture;

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
        roomsFuture ?? Future.value(<PublicRoomsChunk>[]),
      ]);

      final users = results[0] as List<Profile>;
      final rooms = results[1] as List<PublicRoomsChunk>;

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

  Future<void> _joinRoom(String roomId) async {
    setState(() => _isLoading = true);
    try {
      final authController = context.read<AuthController>();
      // Check if already joined
      var room = authController.client?.getRoomById(roomId);

      if (room == null) {
        // Try to join
        final newRoomId = await authController.client?.joinRoom(roomId);
        if (newRoomId != null) {
          room = authController.client?.getRoomById(newRoomId);
        }
      }

      if (mounted && room != null) {
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(builder: (_) => ChatScreen(room: room!)),
        );
      } else {
        if (mounted) {
          setState(() {
            _error = "Could not join room";
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
            _error = "Could not create chat";
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

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;
    final client = context.read<AuthController>().client;

    return CupertinoPageScaffold(
      backgroundColor: palette.scaffoldBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: palette.barBackground,
        middle: const Text('New Chat'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Cancel'),
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
                placeholder: 'Search user (e.g. @user:matrix.org)',
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
                    // Try to join directly if it looks like a room alias
                    _joinRoom(text);
                  } else {
                    _performSearch(text);
                  }
                },
              ),
            ),

            // "Create Group" Button (Only if search is empty)
            if (_searchController.text.isEmpty)
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => const CreateGroupScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: palette.scaffoldBackground,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: palette.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.person_3_fill,
                          color: palette.primary,
                          size: 24,
                        ),
                      ),
                      const Gap(12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Group',
                            style: TextStyle(
                              color: palette.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Create a new group chat',
                            style: TextStyle(
                              color: palette.secondaryText,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            if (_searchController.text.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 76),
                child: Container(color: palette.separator, height: 0.5),
              ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: CupertinoActivityIndicator(),
              ),
            if (_error != null && !_isLoading)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _error!,
                  style: const TextStyle(color: CupertinoColors.systemGrey),
                ),
              ),
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
                                  userId: room.roomId, // fallback
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
                                              .withOpacity(0.7),
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
