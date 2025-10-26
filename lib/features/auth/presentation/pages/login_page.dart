import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vlone_blog_app/core/constants/constants.dart';
import 'package:vlone_blog_app/core/utils/snackbar_utils.dart';
import 'package:vlone_blog_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vlone_blog_app/features/auth/presentation/widgets/auth_form.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    //Use the app-level one.
    // The AuthBloc is provided in MyApp's MultiBlocProvider.
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            // navigate to feed. MyApp already listens too, but this local listener
            // ensures an immediate response inside this page as well.
            if (context.mounted) context.go(Constants.feedRoute);
          } else if (state is AuthError) {
            SnackbarUtils.showError(context, state.message);
          }
        },
        child: const AuthForm(isLogin: true),
      ),
    );
  }
}
