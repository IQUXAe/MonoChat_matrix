import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monochat/controllers/auth_controller.dart';
import 'package:monochat/controllers/room_list_controller.dart';
import 'package:monochat/data/repositories/matrix_auth_repository.dart';
import 'package:monochat/data/repositories/matrix_room_repository.dart';
import 'package:monochat/main.dart';
import 'package:monochat/services/matrix_service.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    final matrixService = MatrixService();
    final authRepository = MatrixAuthRepository(matrixService);
    final roomRepository = MatrixRoomRepository(matrixService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: matrixService),
          ChangeNotifierProvider(create: (_) => AuthController(authRepository)),
          ChangeNotifierProvider(
            create: (_) => RoomListController(roomRepository),
          ),
        ],
        child: const MonoChatApp(),
      ),
    );

    expect(find.byType(CupertinoApp), findsOneWidget);
  });
}
