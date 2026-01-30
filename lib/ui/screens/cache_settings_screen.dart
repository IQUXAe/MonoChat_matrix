import 'package:flutter/cupertino.dart';
import 'package:gap/gap.dart';
import 'package:monochat/controllers/theme_controller.dart';
import 'package:monochat/services/cache/secure_cache_service.dart';
import 'package:provider/provider.dart';
import '../theme/app_palette.dart';

class CacheSettingsScreen extends StatefulWidget {
  const CacheSettingsScreen({super.key});

  @override
  State<CacheSettingsScreen> createState() => _CacheSettingsScreenState();
}

class _CacheSettingsScreenState extends State<CacheSettingsScreen> {
  int _totalSize = 0;
  bool _isLoading = true;
  Map<String, int> _categorySizes = {};

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  Future<void> _loadSize() async {
    final service = SecureCacheService();
    final newCategorySizes = <String, int>{};

    for (final cat in ['image', 'video', 'file', 'metadata', 'avatar']) {
      final size = await service.getCacheSize(category: cat);
      newCategorySizes[cat] = size;
    }

    // Also get uncategorized if any (pass null) but total calculation in service sums all?
    // Actually getCacheSize() without args sums everything.
    // So let's rely on sum of categories + uncategorized?
    // SecureCacheService().getCacheSize() returns TOTAL.
    // SecureCacheService().getCacheSize(category: '...') returns for that category.

    final realTotal = await service.getCacheSize();

    if (mounted) {
      setState(() {
        _totalSize = realTotal;
        _categorySizes = newCategorySizes;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearCache({String? category}) async {
    setState(() => _isLoading = true);
    if (category == null) {
      await SecureCacheService().nuke();
      await SecureCacheService().init();
    } else {
      await SecureCacheService().clearCategory(category);
    }
    await _loadSize();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _getCategoryName(String key) {
    switch (key) {
      case 'image':
        return 'Photos';
      case 'video':
        return 'Videos';
      case 'file':
        return 'Files';
      case 'metadata':
        return 'Metadata (Spaces)';
      case 'avatar':
        return 'Avatars';
      default:
        return key.toUpperCase();
    }
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
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const Gap(32),
            // Usage Chart (Simulated Visual)
            Center(
              child: Container(
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

            // Categories
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: palette.barBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (!_isLoading)
                      ..._categorySizes.entries.map((e) {
                        return _buildActionTile(
                          palette,
                          title: _getCategoryName(e.key),
                          subtitle: _formatSize(e.value),
                          onTap: () => _clearCache(category: e.key),
                          isDestructive: false, // Individual clears are routine
                          showDivider: true,
                        );
                      }),

                    _buildActionTile(
                      palette,
                      title: 'Clear All Cache',
                      subtitle: _formatSize(_totalSize),
                      isDestructive: true,
                      onTap: _clearCache,
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ),
            const Gap(32),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    AppPalette palette, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool showDivider = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: showDivider
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: palette.separator, width: 0.5),
                ),
              )
            : null,
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
