import 'package:flutter/cupertino.dart';
import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/ui/widgets/matrix_avatar.dart';
import 'package:provider/provider.dart';
import 'package:gap/gap.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AuthController>();
    final client = controller.client;

    if (client == null) return const SizedBox.shrink();

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Profile'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const Gap(32),
            Center(
              child: FutureBuilder(
                future: client.fetchOwnProfile(),
                builder: (context, snapshot) {
                  return Column(
                    children: [
                      MatrixAvatar(
                        avatarUrl: snapshot.data?.avatarUrl,
                        name: snapshot.data?.displayName ?? client.userID,
                        client: client,
                        size: 100,
                      ),
                      const Gap(16),
                      Text(
                        snapshot.data?.displayName ?? 'No Name',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        client.userID ?? '',
                        style: const TextStyle(color: CupertinoColors.systemGrey),
                      ),
                    ],
                  );
                }
              ),
            ),
            const Gap(32),
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  title: const Text('Logout', style: TextStyle(color: CupertinoColors.systemRed)),
                  leading: const Icon(CupertinoIcons.arrow_right_square, color: CupertinoColors.systemRed),
                  onTap: () {
                    showCupertinoDialog(
                      context: context,
                      builder: (c) => CupertinoAlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.pop(c),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            onPressed: () {
                              Navigator.pop(c);
                              Navigator.pop(context);
                              controller.logout();
                            },
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
