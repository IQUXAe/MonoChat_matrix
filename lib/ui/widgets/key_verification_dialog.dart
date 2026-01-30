import 'package:flutter/cupertino.dart';
// For some icons if needed, or stick to Cupertino
import 'package:matrix/encryption.dart';

class KeyVerificationDialog extends StatefulWidget {
  final KeyVerification request;

  const KeyVerificationDialog({super.key, required this.request});

  static Future<bool?> show(BuildContext context, KeyVerification request) {
    return showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => KeyVerificationDialog(request: request),
    );
  }

  @override
  State<KeyVerificationDialog> createState() => _KeyVerificationDialogState();
}

class _KeyVerificationDialogState extends State<KeyVerificationDialog> {
  void Function()? _originalOnUpdate;

  @override
  void initState() {
    super.initState();
    _originalOnUpdate = widget.request.onUpdate;
    widget.request.onUpdate = () {
      _originalOnUpdate?.call();
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    widget.request.onUpdate = _originalOnUpdate;
    if (![
      KeyVerificationState.error,
      KeyVerificationState.done,
    ].contains(widget.request.state)) {
      widget.request.cancel('m.user');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    var title = 'Verification';
    var actions = <Widget>[];

    switch (widget.request.state) {
      case KeyVerificationState.askSSSS:
        // Secure Storage / Key Backup Passphrase
        // For simplicity, we might skip this or implement basic input.
        // Basic input implementation.
        final controller = TextEditingController();
        title = 'Secure Storage';
        content = Column(
          children: [
            const Text(
              'Please enter your Secure Storage passphrase or key to verify.',
            ),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: controller,
              placeholder: 'Passphrase or Recovery Key',
              obscureText: true,
            ),
          ],
        );
        actions = [
          CupertinoDialogAction(
            child: const Text('Skip'),
            onPressed: () => widget.request.openSSSS(skip: true),
          ),
          CupertinoDialogAction(
            child: const Text('Submit'),
            onPressed: () =>
                widget.request.openSSSS(keyOrPassphrase: controller.text),
          ),
        ];
        break;

      case KeyVerificationState.askAccept:
        title = 'Verification Request';
        content = Text(
          'Accept verification request from ${widget.request.userId}?',
        );
        actions = [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Reject'),
            onPressed: () {
              widget.request.rejectVerification();
              Navigator.pop(context, false);
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Accept'),
            onPressed: () => widget.request.acceptVerification(),
          ),
        ];
        break;

      case KeyVerificationState.askChoice:
      case KeyVerificationState.waitingAccept:
        title = 'Waiting...';
        content = const Column(
          children: [
            CupertinoActivityIndicator(radius: 14),
            SizedBox(height: 16),
            Text('Waiting for partner to accept...'),
          ],
        );
        actions = [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () {
              widget.request.cancel();
              Navigator.pop(context, false);
            },
          ),
        ];
        break;

      case KeyVerificationState.askSas:
        // SAS Comparison
        if (widget.request.sasTypes.contains('emoji')) {
          title = 'Compare Emojis';
          content = Column(
            children: [
              const Text('Do these emojis match the ones on the other device?'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: widget.request.sasEmojis
                    .map(
                      (e) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(e.emoji, style: const TextStyle(fontSize: 32)),
                          Text(e.name, style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        } else {
          title = 'Compare Numbers';
          final numbers = widget.request.sasNumbers;
          content = Column(
            children: [
              const Text('Do these numbers match?'),
              const SizedBox(height: 16),
              Text(
                '${numbers[0]} - ${numbers[1]} - ${numbers[2]}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        }
        actions = [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('No Match'),
            onPressed: () => widget.request.rejectSas(),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('They Match'),
            onPressed: () => widget.request.acceptSas(),
          ),
        ];
        break;

      case KeyVerificationState.waitingSas:
        title = 'Waiting...';
        content = const Column(
          children: [
            CupertinoActivityIndicator(),
            SizedBox(height: 16),
            Text('Waiting for partner to confirm...'),
          ],
        );
        break;

      case KeyVerificationState.done:
        title = 'Verified!';
        content = const Column(
          children: [
            Icon(
              CupertinoIcons.checkmark_circle_fill,
              color: CupertinoColors.activeGreen,
              size: 64,
            ),
            SizedBox(height: 16),
            Text('Session verified successfully.'),
          ],
        );
        actions = [
          CupertinoDialogAction(
            child: const Text('Done'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ];
        break;

      case KeyVerificationState.error:
        title = 'Error';
        content = Column(
          children: [
            const Icon(
              CupertinoIcons.xmark_circle_fill,
              color: CupertinoColors.systemRed,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text('Verification failed: ${widget.request.canceledReason}'),
          ],
        );
        actions = [
          CupertinoDialogAction(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context, false),
          ),
        ];
        break;

      default:
        content = const Column(
          children: [
            CupertinoActivityIndicator(),
            SizedBox(height: 16),
            Text('Incoming verification request...'),
          ],
        );
    }

    return CupertinoAlertDialog(
      title: Text(title),
      content: Padding(padding: const EdgeInsets.only(top: 12), child: content),
      actions: actions,
    );
  }
}
