import 'dart:async';

extension StreamExtension on Stream {
  /// Returns a new Stream which outputs only `true` for every update of the original
  /// stream, ratelimited by the Duration t
  Stream<bool> rateLimit(Duration t) {
    final controller = StreamController<bool>();
    Timer? timer;
    var gotMessage = false;
    Function? onMessage;

    onMessage = () {
      if (controller.isClosed) {
        return;
      }
      if (timer == null) {
        gotMessage = false;
        controller.add(true);
        timer = Timer(t, () {
          timer = null;
          if (gotMessage) {
            onMessage?.call();
          }
        });
      } else {
        gotMessage = true;
      }
    };

    final subscription = listen(
      (_) => onMessage?.call(),
      onDone: controller.close,
      onError: (e, s) => controller.addError(e, s),
    );

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };
    return controller.stream;
  }
}
