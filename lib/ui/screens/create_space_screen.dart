import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart' as matrix;
import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/controllers/space_controller.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/l10n/generated/app_localizations.dart';
import 'package:monochat/ui/screens/space_view_screen.dart';
import 'package:provider/provider.dart';

// =============================================================================
// CREATE SPACE SCREEN
// =============================================================================

/// Screen for creating a new Matrix Space.
///
/// Allows users to:
/// - Set space name and topic
/// - Choose visibility (public/private)
/// - Add optional avatar
class CreateSpaceScreen extends StatefulWidget {
  const CreateSpaceScreen({super.key});

  @override
  State<CreateSpaceScreen> createState() => _CreateSpaceScreenState();
}

class _CreateSpaceScreenState extends State<CreateSpaceScreen> {
  final _nameController = TextEditingController();
  final _topicController = TextEditingController();
  final _aliasController = TextEditingController();

  bool _isPublic = false;
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
        setState(() => _avatarFile = pickedFile);
      }
    } catch (_) {
      // Handle permission errors
    }
  }

  void _showAvatarOptions() {
    final l10n = AppLocalizations.of(context)!;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
            child: Text(l10n.takePhoto),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
            child: Text(l10n.choosePhoto),
          ),
          if (_avatarFile != null)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                setState(() => _avatarFile = null);
              },
              child: Text(l10n.remove),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }

  Future<void> _createSpace() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);

    try {
      final client = context.read<AuthController>().client!;

      // Prepare initial state
      final initialState = <matrix.StateEvent>[];

      // Avatar
      if (_avatarFile != null) {
        final bytes = await _avatarFile!.readAsBytes();
        final mxcUri = await client.uploadContent(
          bytes,
          filename: _avatarFile!.name,
          contentType: 'image/jpeg',
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
        visibility: _isPublic
            ? matrix.Visibility.public
            : matrix.Visibility.private,
        creationContent: {'type': 'm.space'},
        preset: _isPublic
            ? matrix.CreateRoomPreset.publicChat
            : matrix.CreateRoomPreset.privateChat,
        powerLevelContentOverride: {'events_default': 100},
        initialState: initialState,
      );

      if (!mounted) return;
      final spaceController = context.read<SpaceController>();
      await spaceController.setActiveSpace(roomId);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(
          builder: (_) => SpaceViewScreen(
            spaceId: roomId,
            onBack: () => Navigator.of(context).pop(),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (c) => CupertinoAlertDialog(
            title: Text(l10n.error),
            content: Text('${l10n.failedToCreateSpace}: $e'),
            actions: [
              CupertinoDialogAction(
                child: Text(l10n.ok),
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
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      backgroundColor: palette.scaffoldBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.createSpace),
        backgroundColor: palette.barBackground,
        previousPageTitle: l10n.cancel,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading || _nameController.text.isEmpty
              ? null
              : _createSpace,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : Text(l10n.create),
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
                    borderRadius: BorderRadius.circular(16),
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
              placeholder: l10n.spaceName,
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
              placeholder: l10n.topicOptional,
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
              l10n.settings.toUpperCase(),
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
                                _isPublic
                                    ? l10n.publicSpace
                                    : l10n.privateSpace,
                                style: TextStyle(
                                  color: palette.text,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                _isPublic
                                    ? l10n.anyoneCanJoin
                                    : l10n.inviteOnly,
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
                          onChanged: (val) => setState(() => _isPublic = val),
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
                        placeholder: l10n.spaceAlias,
                        decoration: null,
                        prefix: Text(
                          '# ',
                          style: TextStyle(color: palette.secondaryText),
                        ),
                        style: TextStyle(color: palette.text),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Info text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                l10n.spaceDescription,
                style: TextStyle(fontSize: 13, color: palette.secondaryText),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
