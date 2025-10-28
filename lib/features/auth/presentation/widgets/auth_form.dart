import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';

class AuthForm extends StatefulWidget {
  final bool isLogin;

  const AuthForm({super.key, required this.isLogin});

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // REMOVE: Removed the _usernameController
  // final _usernameController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    // REMOVE: Dispose for _usernameController is removed
    // _usernameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (widget.isLogin) {
        context.read<AuthBloc>().add(
          LoginEvent(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          ),
        );
      } else {
        context.read<AuthBloc>().add(
          SignupEvent(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            // REMOVE: Removed the username parameter from SignupEvent
            // username: _usernameController.text.trim(),
          ),
        );
      }
    }
  }

  void _navigateToOtherAuth() {
    if (widget.isLogin) {
      context.go(Constants.signupRoute);
    } else {
      context.go(Constants.loginRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ✅ ADDED: Modern Logo Placement
                // Place the logo prominently at the top for brand recognition.
                // Assuming 'assets/logo.png' exists based on pubspec.yaml.
                Center(
                  child: Image.asset(
                    'assets/logo.png',
                    height: 90, // Recommended size for a modern brand mark
                  ),
                ),
                const SizedBox(height: 48), // Good vertical spacing

                Text(
                  widget.isLogin ? 'Welcome Back' : 'Create Account',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isLogin
                      ? 'Sign in to explore the latest blogs'
                      : 'Join us to share your thoughts',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final bool isLoading = state is AuthLoading;
                    return Form(
                      key: _formKey,
                      child: AbsorbPointer(
                        absorbing: isLoading,
                        child: Column(
                          children: [
                            // REMOVE: Removed the Username TextFormField and the SizedBox
                            /*
                            if (!widget.isLogin)
                              TextFormField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: theme.scaffoldBackgroundColor
                                      .withOpacity(0.5),
                                ),
                                validator: (value) =>
                                    value!.isEmpty ? 'Enter username' : null,
                              ),
                            if (!widget.isLogin) const SizedBox(height: 16),
                            */
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: theme.scaffoldBackgroundColor
                                    .withOpacity(0.5),
                              ),
                              validator: (value) {
                                if (value!.isEmpty) return 'Enter email';
                                if (!RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                ).hasMatch(value)) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                              keyboardType: TextInputType.emailAddress,
                            ),
                            // NOTE: The SizedBox after the removed username field is also removed,
                            // if it was there, but the next SizedBox after the email field remains.
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: _togglePasswordVisibility,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: theme.scaffoldBackgroundColor
                                    .withOpacity(0.5),
                              ),
                              validator: (value) {
                                if (value!.length < 8) {
                                  return 'Password must be at least 8 characters';
                                }
                                return null;
                              },
                              obscureText: _obscurePassword,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Text(widget.isLogin ? 'Login' : 'Signup'),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.isLogin
                                      ? "Don't have an account?"
                                      : 'Already have an account?',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                TextButton(
                                  onPressed: isLoading
                                      ? null
                                      : _navigateToOtherAuth,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Text(
                                    widget.isLogin ? 'Sign up' : 'Login',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
