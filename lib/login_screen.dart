import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome to kien',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 32),

            // Placeholder: Firebase email sign-in button
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: () {
                  // TODO: Integrate Firebase email sign-in
                },
                child: const Text('Sign in with Email'),
              ),
            ),

            const SizedBox(height: 16),

            // Placeholder: Google sign-in button
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Integrate Google sign-in
                },
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Firebase Auth and Google Sign-In will be integrated here later.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

