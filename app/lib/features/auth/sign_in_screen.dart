import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/account_controller.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final s = S.of(context);
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = s.t('signin_invalid_email'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AccountController>().auth.sendCode(email);
      setState(() => _codeSent = true);
    } catch (_) {
      setState(() => _error = s.t('error_generic'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final s = S.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AccountController>().auth.verifyCode(_email.text.trim(), _code.text.trim());
    } catch (_) {
      setState(() => _error = s.t('signin_invalid_code'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('signin_title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(s.t('signin_body'), style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: s.t('email'), border: const OutlineInputBorder()),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                decoration: InputDecoration(labelText: s.t('code'), border: const OutlineInputBorder()),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : (_codeSent ? _verify : _send),
              child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_codeSent ? s.t('verify') : s.t('send_code')),
            ),
          ],
        ),
      ),
    );
  }
}
