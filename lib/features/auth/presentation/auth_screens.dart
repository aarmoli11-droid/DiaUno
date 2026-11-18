import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/brand.dart';
import '../../../core/config/env.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/tokens.dart';
import '../application/auth_controller.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = paletteFor(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.eco_rounded, color: p.primary, size: 52),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    Brand.name,
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    Brand.tagline,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  Text(
                    'Organiza tus proyectos, tu tiempo y tu día.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Un espacio para tus tareas, agenda, finanzas compartidas y progreso.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.push('/auth/register'),
                      child: const Text('Crear cuenta'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.push('/auth/login'),
                      child: const Text('Iniciar sesión'),
                    ),
                  ),
                  if (Env.enableGoogleOAuth) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _google(ref, context),
                        icon: const Icon(Icons.g_mobiledata, size: 20),
                        label: const Text('Continuar con Google'),
                      ),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.lg),
                      child: Text(
                        'Google: pendiente de configurar el proveedor OAuth y las URLs de retorno.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _google(WidgetRef ref, BuildContext context) async {
    try {
      final uri = await ref
          .read(authRepositoryProvider)
          .googleAuthorizationUrl();
      // El flujo queda preparado: abre el consentimiento real de Supabase.
      // El retorno a la app requiere registrar el esquema de callback por
      // plataforma (pendiente documentado; no se simula autenticación).
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Completa el acceso en el navegador. El retorno a la app está pendiente de configurar.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google OAuth no está disponible: $e')),
        );
      }
    }
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    try {
      await ref
          .read(authActionsProvider.notifier)
          .signIn(email: _email.text, password: _password.text);
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authActionsProvider);
    return AuthFormScaffold(
      title: 'Bienvenido de nuevo',
      subtitle: 'Entra para continuar con tu día.',
      formKey: _formKey,
      error: _error,
      loading: loading,
      onSubmit: _submit,
      fields: [
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Correo',
            prefixIcon: Icon(Icons.mail_outline),
          ),
          validator: (v) => v == null || !v.contains('@')
              ? 'Introduce un correo válido'
              : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          validator: (v) =>
              v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
        ),
      ],
      footer: [
        TextButton(
          onPressed: () => context.push('/auth/reset'),
          child: const Text('Olvidé mi contraseña'),
        ),
        TextButton(
          onPressed: () => context.push('/auth/register'),
          child: const Text('Crear una cuenta'),
        ),
      ],
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _notice = null;
    });
    try {
      await ref
          .read(authActionsProvider.notifier)
          .signUp(
            displayName: _name.text,
            email: _email.text,
            password: _password.text,
          );
      if (!mounted) return;
      if (ref.read(supabaseProvider).auth.currentSession != null) {
        context.go('/home');
      } else {
        setState(
          () => _notice =
              'Revisa tu correo para confirmar la cuenta. Después podrás iniciar sesión.',
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authActionsProvider);
    return AuthFormScaffold(
      title: 'Crea tu espacio',
      subtitle: 'Sólo necesitas unos datos para empezar.',
      formKey: _formKey,
      error: _error,
      notice: _notice,
      loading: loading,
      onSubmit: _submit,
      fields: [
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre visible'),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Escribe tu nombre' : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Correo'),
          validator: (v) => v == null || !v.contains('@')
              ? 'Introduce un correo válido'
              : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: const InputDecoration(labelText: 'Contraseña'),
          validator: (v) =>
              v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
        ),
      ],
      footer: [
        TextButton(
          onPressed: () => context.go('/auth/login'),
          child: const Text('Ya tengo cuenta'),
        ),
      ],
    );
  }
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref.read(authActionsProvider.notifier).resetPassword(_email.text);
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      title: 'Recuperar acceso',
      subtitle: 'Te enviaremos un enlace seguro a tu correo.',
      formKey: _formKey,
      error: _error,
      notice: _sent
          ? 'Enlace enviado. Abre el correo en este dispositivo y pulsa el enlace '
                'para elegir una contraseña nueva.'
          : null,
      loading: ref.watch(authActionsProvider),
      onSubmit: _submit,
      fields: [
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Correo'),
          validator: (v) => v == null || !v.contains('@')
              ? 'Introduce un correo válido'
              : null,
        ),
      ],
      footer: [
        TextButton(
          onPressed: () => context.go('/auth/login'),
          child: const Text('Volver al inicio de sesión'),
        ),
      ],
    );
  }
}

/// Pantalla que se muestra sólo mientras hay una sesión de `passwordRecovery`.
/// El enlace de Supabase ya ha validado el token; aquí sólo se guarda la clave.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    try {
      await ref
          .read(authActionsProvider.notifier)
          .updatePassword(_password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Contraseña actualizada. Entra con tu nueva contraseña.',
          ),
        ),
      );
      context.go('/auth/login');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      title: 'Nueva contraseña',
      subtitle:
          'El enlace de recuperación es válido. Elige una contraseña nueva.',
      formKey: _formKey,
      error: _error,
      loading: ref.watch(authActionsProvider),
      onSubmit: _submit,
      fields: [
        TextFormField(
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: const InputDecoration(
            labelText: 'Nueva contraseña',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          validator: (v) =>
              v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _confirm,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Repite la contraseña',
            prefixIcon: Icon(Icons.lock_reset_outlined),
          ),
          validator: (v) =>
              v != _password.text ? 'Las contraseñas no coinciden' : null,
        ),
      ],
      footer: [
        TextButton(
          onPressed: () async {
            await ref.read(authActionsProvider.notifier).signOut();
            if (context.mounted) context.go('/auth/welcome');
          },
          child: const Text('Cancelar y volver al inicio'),
        ),
      ],
    );
  }
}

class AuthFormScaffold extends StatelessWidget {
  const AuthFormScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.formKey,
    required this.fields,
    required this.onSubmit,
    required this.loading,
    this.error,
    this.notice,
    this.footer = const [],
  });

  final String title;
  final String subtitle;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final VoidCallback onSubmit;
  final bool loading;
  final String? error;
  final String? notice;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    IconButton(
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.zero,
                      onPressed: () => context.go('/auth/welcome'),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: p.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ...fields,
                    if (error != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        error!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: p.error),
                      ),
                    ],
                    if (notice != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        notice!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: p.success),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: loading ? null : onSubmit,
                      child: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continuar'),
                    ),
                    ...footer,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
