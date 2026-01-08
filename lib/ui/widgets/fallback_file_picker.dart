import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // For Icons
import 'package:path/path.dart' as p;

class FallbackFilePicker extends StatefulWidget {
  final Function(File) onFileSelected;
  final List<String>? allowedExtensions;

  const FallbackFilePicker({
    super.key,
    required this.onFileSelected,
    this.allowedExtensions,
  });

  @override
  State<FallbackFilePicker> createState() => _FallbackFilePickerState();
}

class _FallbackFilePickerState extends State<FallbackFilePicker> {
  late Directory _currentDir;
  List<FileSystemEntity> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initDir();
  }

  Future<void> _initDir() async {
    // Start at Home directory
    final envVars = Platform.environment;
    final home = envVars['HOME'] ?? '/';
    _currentDir = Directory(home);
    await _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final List<FileSystemEntity> entities = await _currentDir.list().toList();

      // Sort: Directories first, then files. Alphabetical.
      entities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase());
      });

      setState(() {
        _files = entities;
        _isLoading = false;
      });
    } catch (e) {
      // Permission denied or other error
      setState(() {
        _files = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _navigate(Directory dir) async {
    _currentDir = dir;
    await _loadFiles();
  }

  void _goUp() {
    final parent = _currentDir.parent;
    if (parent.path != _currentDir.path) {
      _navigate(parent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Icon(CupertinoIcons.arrow_up_circle),
                  onPressed: _goUp,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentDir.path,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                CupertinoButton(
                  child: const Text('Close'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : _files.isEmpty
                ? const Center(child: Text("Empty or Access Denied"))
                : ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final entity = _files[index];
                      final name = p.basename(entity.path);
                      final isDir = entity is Directory;

                      // Filter logic if needed
                      if (!isDir && widget.allowedExtensions != null) {
                        final ext = p
                            .extension(name)
                            .replaceAll('.', '')
                            .toLowerCase();
                        if (!widget.allowedExtensions!.contains(ext)) {
                          // Make non-selectable or hide? Let's hide for now or dim.
                          // Simplest is to just show everything but disable tap on bad files.
                        }
                      }

                      return Material(
                        // For ripple
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Icon(
                            isDir
                                ? CupertinoIcons.folder_solid
                                : CupertinoIcons.doc_text,
                            color: isDir
                                ? CupertinoColors.activeBlue
                                : CupertinoColors.systemGrey,
                          ),
                          title: Text(name),
                          onTap: () {
                            if (isDir) {
                              _navigate(entity as Directory);
                            } else {
                              widget.onFileSelected(entity as File);
                              Navigator.pop(context);
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
