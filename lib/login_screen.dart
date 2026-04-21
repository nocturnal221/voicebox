import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isAdmin = false;
  bool _isLoading = false;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter email and password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Login failed. Please try again.');
      }

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role, assigned_category')
          .eq('id', response.user!.id)
          .single();

      final role = profile['role'] as String? ?? 'user';
      final assignedCategory = profile['assigned_category']?.toString();
      final bool isActuallyAdmin = role == 'main_admin' || role == 'sub_admin';

      if (isAdmin && !isActuallyAdmin) {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access denied. This account is not an admin.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!isAdmin && isActuallyAdmin) {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access denied. Please use the admin toggle.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (role == 'sub_admin' &&
          (assignedCategory == null || assignedCategory.isEmpty)) {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This admin account has no assigned category yet.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } catch (e) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome Back',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              // const SizedBox(height: 8),
              // Text(
              //   'Login as a general user, DSW, or category admin.',
              //   style: theme.textTheme.bodyLarge?.copyWith(
              //     color: theme.colorScheme.onSurfaceVariant,
              //   ),
              // ),
              const SizedBox(height: 40),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: const Text('Login As'),
                  subtitle: Text(isAdmin ? 'Admin' : 'General User'),
                  value: isAdmin,
                  onChanged: (value) => setState(() => isAdmin = value),
                  secondary: Icon(
                    isAdmin ? Icons.admin_panel_settings : Icons.person_outline,
                    color: isAdmin ? theme.colorScheme.primary : null,
                  ),
                ),
              ),
              //const SizedBox(height: 12),
              // Container(
              //   width: double.infinity,
              //   padding: const EdgeInsets.all(12),
              //   decoration: BoxDecoration(
              //     color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              //     borderRadius: BorderRadius.circular(12),
              //   ),
              //   child: Text(
              //     isAdmin
              //         ? 'DSW can see all problems. Category admins can only see and respond to their own assigned category.'
              //         : 'General users can create complaints and track their own submissions.',
              //     style: theme.textTheme.bodyMedium,
              //   ),
              // ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('New User? ', style: theme.textTheme.bodyMedium),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Register',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
