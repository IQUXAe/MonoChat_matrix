import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart' as matrix;
import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/ui/screens/chat_screen.dart';
import 'package:provider/provider.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _topicController = TextEditingController();
  final _aliasController = TextEditingController();

  bool _isPublic = false;
  bool _isSearchable = true;
  bool _isEncrypted = true;
  bool _isLoading = false;
  XFile? _avatarFile;

  @override
  void dispose() {
    _nameController.dispose();
    _topicController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _avatarFile = pickedFile;
        });
      }
    } catch (_) {
      // Handle permission errors etc
    }
  }

  void _showAvatarOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
            child: const Text('Take Photo'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
            child: const Text('Choose from Library'),
          ),
          if (_avatarFile != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                setState(() => _avatarFile = null);
              },
              child: const Text('Remove Photo'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final client = context.read<AuthController>().client!;

      // Determine preset and visibility
      final preset = _isPublic
          ? matrix.CreateRoomPreset.publicChat
          : matrix.CreateRoomPreset.privateChat;

      final visibility = _isPublic && _isSearchable
          ? matrix.Visibility.public
          : matrix.Visibility.private;

      // Prepare initial state
      final initialState = <matrix.StateEvent>[];

      // Encryption
      if (_isEncrypted && !_isPublic) {
        initialState.add(
          matrix.StateEvent(
            content: {'algorithm': 'm.megolm.v1.aes-sha2'},
            type: 'm.room.encryption',
            stateKey: '',
          ),
        );
      }

      // Avatar
      if (_avatarFile != null) {
        // Upload image first
        final bytes = await _avatarFile!.readAsBytes();
        final matrixFile = matrix.MatrixFile(
          bytes: bytes,
          name: _avatarFile!.name,
        );
        final mxcUri = await client.uploadContent(
          matrixFile.bytes,
          filename: matrixFile.name,
          contentType: 'image/jpeg', // Simple assumption or detect mime
        );

        initialState.add(
          matrix.StateEvent(
            content: {'url': mxcUri.toString()},
            type: 'm.room.avatar',
            stateKey: '',
          ),
        );
      }

      final roomId = await client.createRoom(
        name: name,
        topic: _topicController.text.trim(),
        roomAliasName: _isPublic ? _aliasController.text.trim() : null,
        visibility: visibility,
        preset: preset,
        initialState: initialState,
      );

      if (mounted) {
        final room = client.getRoomById(roomId);
        if (room != null) {
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(builder: (_) => ChatScreen(room: room)),
          );
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (c) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Could not create group: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(c),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;

    return CupertinoPageScaffold(
      backgroundColor: palette.scaffoldBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('New Group'),
        backgroundColor: palette.barBackground,
        previousPageTitle: 'Back',
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading || _nameController.text.isEmpty
              ? null
              : _createGroup,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : const Text('Create'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 16),
            // Avatar Picker
            Center(
              child: GestureDetector(
                onTap: _showAvatarOptions,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: palette.inputBackground,
                    shape: BoxShape.circle,
                    image: _avatarFile != null
                        ? DecorationImage(
                            image: FileImage(File(_avatarFile!.path)),
                            fit: BoxFit.cover,
                          )
                        : null,
                    border: Border.all(color: palette.separator, width: 1),
                  ),
                  child: _avatarFile == null
                      ? Icon(
                          CupertinoIcons.camera_fill,
                          size: 40,
                          color: palette.secondaryText,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Name
            CupertinoTextField(
              controller: _nameController,
              placeholder: 'Group Name',
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.inputBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Topic
            CupertinoTextField(
              controller: _topicController,
              placeholder: 'Topic (optional)',
              padding: const EdgeInsets.all(12),
              minLines: 1,
              maxLines: 3,
              decoration: BoxDecoration(
                color: palette.inputBackground,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 32),

            // Settings Section
            Text(
              'SETTINGS',
              style: TextStyle(
                color: palette.secondaryText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: palette.inputBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  // Public/Private Toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isPublic
                              ? CupertinoIcons.globe
                              : CupertinoIcons.lock_fill,
                          color: palette.text,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isPublic ? 'Public Group' : 'Private Group',
                                style: TextStyle(
                                  color: palette.text,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                _isPublic ? 'Anyone can join' : 'Invite only',
                                style: TextStyle(
                                  color: palette.secondaryText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoSwitch(
                          value: _isPublic,
                          onChanged: (val) {
                            setState(() {
                              _isPublic = val;
                              _isEncrypted = !_isPublic;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  // Alias input if public
                  if (_isPublic) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 56, right: 0),
                      child: Container(height: 0.5, color: palette.separator),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: CupertinoTextField(
                        controller: _aliasController,
                        placeholder: 'Room Alias (e.g. my-group)',
                        decoration: null,
                        prefix: Text(
                          '# ',
                          style: TextStyle(color: palette.secondaryText),
                        ),
                        style: TextStyle(color: palette.text),
                      ),
                    ),
                  ],

                  // Searchable Toggle (Only for public groups)
                  if (_isPublic) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 56, right: 0),
                      child: Container(height: 0.5, color: palette.separator),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.search, color: palette.text),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.searchable,
                                  style: TextStyle(
                                    color: palette.text,
                                    fontSize: 17,
                                  ),
                                ),
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.searchableDescription,
                                  style: TextStyle(
                                    color: palette.secondaryText,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CupertinoSwitch(
                            value: _isSearchable,
                            onChanged: (val) {
                              setState(() => _isSearchable = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  Padding(
                    padding: const EdgeInsets.only(left: 56, right: 0),
                    child: Container(height: 0.5, color: palette.separator),
                  ),

                  // Encryption Toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.shield_fill,
                          color: _isEncrypted
                              ? CupertinoColors.activeGreen
                              : palette.secondaryText,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Encryption',
                                style: TextStyle(
                                  color: palette.text,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                _isEncrypted
                                    ? 'End-to-end encrypted'
                                    : 'Unencrypted',
                                style: TextStyle(
                                  color: palette.secondaryText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoSwitch(
                          value: _isEncrypted,
                          onChanged: _isPublic
                              ? null
                              : (val) {
                                  setState(() => _isEncrypted = val);
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
