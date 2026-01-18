import 'package:flutter/cupertino.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/services/cache/secure_cache_service.dart';
import 'package:provider/provider.dart';
import 'package:gap/gap.dart';

class CacheSettingsScreen extends StatefulWidget {
  const CacheSettingsScreen({super.key});

  @override
  State<CacheSettingsScreen> createState() => _CacheSettingsScreenState();
}

class _CacheSettingsScreenState extends State<CacheSettingsScreen> {
  int _totalSize = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  Future<void> _loadSize() async {
    final size = await SecureCacheService().getCacheSize();
    if (mounted) {
      setState(() {
        _totalSize = size;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCache() async {
    setState(() => _isLoading = true);
    await SecureCacheService().nuke();
    await SecureCacheService().init(); // Re-init after nuke
    await _loadSize();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<ThemeController>().palette;

    return CupertinoPageScaffold(
      backgroundColor: palette.scaffoldBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: palette.barBackground,
        border: null,
        middle: Text('Storage Usage', style: TextStyle(color: palette.text)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Gap(32),
            // Usage Chart (Simulated Visual)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.scaffoldBackground,
                border: Border.all(
                  color: _totalSize > 0 ? palette.primary : palette.separator,
                  width: 8,
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLoading ? '...' : _formatSize(_totalSize),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: palette.text,
                    ),
                  ),
                  Text(
                    'Used',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(32),

            // Info Text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'MonoChat uses a secure encrypted cache to store photos and videos. '
                'You can clear this cache to free up space on your device. '
                'Files will be re-downloaded when needed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.secondaryText, fontSize: 14),
              ),
            ),

            const Gap(32),

            // Clear Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: palette.barBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildActionTile(
                      palette,
                      title: 'Clear Cache',
                      subtitle: _formatSize(_totalSize),
                      isDestructive: true,
                      onTap: _clearCache,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    palette, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      color: isDestructive
                          ? CupertinoColors.systemRed
                          : palette.text,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 17, color: palette.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}
