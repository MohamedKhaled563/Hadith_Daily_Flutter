import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import 'bulk_add_page.dart';
import 'pending_queue_page.dart';
import 'rotation_order_page.dart';

class DashboardApp extends StatelessWidget {
  const DashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'لوحة الإشراف — طيّب قلبك',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3C5940),
        fontFamily: 'Tajawal',
      ),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const _AuthGate(),
    );
  }
}

/// Three states: signed out → sign-in form; signed in but not a
/// moderator/admin → access-denied notice; signed in with the role →
/// the dashboard itself. The role check force-refreshes the ID token
/// (`getIdTokenResult(true)`) every time this rebuilds for a signed-in
/// user, since a role granted moments ago (tool/set_role.py) wouldn't
/// otherwise show up until some unrelated token refresh happened to occur.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) return const _SignInScreen();

        return FutureBuilder<IdTokenResult>(
          // forceRefresh: true — see the class doc above.
          future: user.getIdTokenResult(true),
          builder: (context, tokenSnapshot) {
            if (!tokenSnapshot.hasData) {
              return const _LoadingScreen();
            }
            final role = tokenSnapshot.data!.claims?['role'] as String?;
            if (role != 'moderator' && role != 'admin') {
              return const _AccessDeniedScreen();
            }
            return const _DashboardHome();
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 56),
              const SizedBox(height: 16),
              const Text(
                'ليس لديك صلاحية الوصول لهذه اللوحة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'هذه الصفحة مخصصة للمشرفين والمديرين فقط.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => AuthService.instance.signOut(),
                child: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInScreen extends StatefulWidget {
  const _SignInScreen();

  @override
  State<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<_SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'تعذّر تسجيل الدخول');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_moon_outlined, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'لوحة الإشراف',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const Text('طيّب قلبك — للمشرفين والمديرين'),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('دخول'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardHome extends StatefulWidget {
  const _DashboardHome();

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final email = AuthService.instance.currentUser?.email ?? '';

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة الإشراف — طيّب قلبك'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: Text(email)),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'تسجيل الخروج',
              onPressed: () => AuthService.instance.signOut(),
            ),
          ],
          bottom: TabBar(
            tabs: const [
              Tab(
                text: 'قائمة المراجعة',
                icon: Icon(Icons.pending_actions_rounded),
              ),
              Tab(text: 'الترتيب والتوزيع', icon: Icon(Icons.shuffle_rounded)),
              Tab(text: 'إضافة بالجملة', icon: Icon(Icons.playlist_add_rounded)),
            ],
            onTap: (i) => setState(() => _tab = i),
          ),
        ),
        body: IndexedStack(
          index: _tab,
          children: const [
            PendingQueuePage(),
            RotationOrderPage(),
            BulkAddPage(),
          ],
        ),
      ),
    );
  }
}
