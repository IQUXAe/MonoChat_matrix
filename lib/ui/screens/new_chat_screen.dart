import 'package:flutter/cupertino.dart';
import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/controllers/room_list_controller.dart';
import 'package:monochat/ui/screens/chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:gap/gap.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _idController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _handleCreate() async {
    final id = _idController.text.trim();
    if (id.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final roomController = context.read<RoomListController>();
      final roomId = await roomController.createDirectChat(id);

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
      } else if (mounted) {
        setState(() {
          _error = 'Failed to create chat';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('New Chat'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter Matrix ID (e.g. @user:matrix.org)',
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const Gap(8),
              CupertinoTextField(
                controller: _idController,
                placeholder: '@username:homeserver',
                autofocus: true,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
                onSubmitted: (_) => _handleCreate(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: CupertinoColors.systemRed,
                      fontSize: 14,
                    ),
                  ),
                ),
              const Gap(24),
              CupertinoButton.filled(
                onPressed: _isLoading ? null : _handleCreate,
                child: _isLoading
                    ? const CupertinoActivityIndicator(
                        color: CupertinoColors.white,
                      )
                    : const Text('Start Chat'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
