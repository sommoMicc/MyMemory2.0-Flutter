import 'package:flutter/widgets.dart';
import 'account.dart';
import 'economy.dart';

class AccountAppleWebButton extends StatelessWidget {
  const AccountAppleWebButton({
    super.key,
    required this.economy,
    required this.provider,
    required this.onPreview,
    required this.onError,
    this.operation = 'login',
    this.enabled = true,
    this.width,
  });
  final EconomyController economy;
  final AccountProvider provider;
  final ValueChanged<AccountSignInPreview> onPreview;
  final ValueChanged<Object> onError;
  final String operation;
  final bool enabled;
  final double? width;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
