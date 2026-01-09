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
      final results = await context.read<RoomListController>().searchUsers(
        query,
      );
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
          _error = results.isEmpty ? 'No users found' : null;
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

  Future<void> _createChat(String mxid) async {
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
                  if (text.contains(':') && _searchResults.isEmpty) {
                    _createChat(text);
                  } else {
                    _performSearch(text);
                  }
                },
              ),
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
              child: ListView.separated(
                itemCount: _searchResults.length,
                separatorBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(left: 76),
                  child: Container(color: palette.separator, height: 0.5),
                ),
                itemBuilder: (context, index) {
                  final profile = _searchResults[index];
                  // If client is null, handle gracefully
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
