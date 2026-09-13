import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/firebase_config.dart';
import '../../../../core/config/oauth_config.dart';
import '../../domain/entities/cloud_provider.dart';
import '../providers/auth_providers.dart';

/// Primeira tela do app. Duas famílias de login, independentes entre si
/// (ver DECISOES.md):
/// - Google/Microsoft: OAuth PKCE, sem backend, dobra como conexão de nuvem.
/// - Email/senha: Firebase Authentication, opção permanente para quem não
///   quer usar conta de terceiros. Não dá acesso a nenhuma nuvem por si só.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

enum _ModoFormulario { entrar, criarConta }

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  _ModoFormulario _modo = _ModoFormulario.entrar;
  bool _enviando = false;
  String? _erroFormulario;
  String? _avisoFormulario;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _enviarFormulario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _enviando = true;
      _erroFormulario = null;
      _avisoFormulario = null;
    });

    final controller = ref.read(authControllerProvider.notifier);
    final email = _emailController.text.trim();
    final senha = _senhaController.text;

    final erro = _modo == _ModoFormulario.entrar
        ? await controller.entrarComEmailSenha(email: email, senha: senha)
        : await controller.criarContaComEmailSenha(email: email, senha: senha);

    if (!mounted) return;
    setState(() {
      _enviando = false;
      _erroFormulario = erro;
    });
  }

  Future<void> _esqueciSenha() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _erroFormulario = 'Digite seu e-mail acima para recuperar a senha.');
      return;
    }
    setState(() {
      _enviando = true;
      _erroFormulario = null;
      _avisoFormulario = null;
    });
    final erro = await ref.read(authControllerProvider.notifier).enviarEmailRecuperacaoSenha(email);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _erroFormulario = erro;
      _avisoFormulario = erro == null ? 'Enviamos um link de recuperação para $email.' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final carregandoOAuth = authState.isLoading;
    final erroOAuth = authState.valueOrNull is AuthUnauthenticated
        ? (authState.valueOrNull as AuthUnauthenticated).erro
        : null;

    final googleConfigurado = OAuthConfig.forProvider(CloudProvider.googleDrive).isConfigured;
    final emailSenhaConfigurado = FirebaseConfig.isConfigured;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Certificados Lattes',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Entre para organizar seus comprovantes e montar o dossiê de '
                      'Prova de Títulos. Seus arquivos ficam salvos na sua própria '
                      'conta — nunca em um servidor compartilhado.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (erroOAuth != null) _caixaMensagem(context, erroOAuth, erro: true),
                    if (erroOAuth != null) const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: (!googleConfigurado || carregandoOAuth)
                          ? null
                          : () => ref.read(authControllerProvider.notifier).loginComGoogle(),
                      icon: carregandoOAuth
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(googleConfigurado ? 'Continuar com Google' : 'Continuar com Google (em breve)'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.login),
                      label: const Text('Continuar com Microsoft (em breve)'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('ou', style: Theme.of(context).textTheme.bodySmall),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (!emailSenhaConfigurado)
                      _caixaMensagem(
                        context,
                        'Login por e-mail e senha ainda não está disponível nesta versão.',
                        erro: false,
                      )
                    else ...[
                      SegmentedButton<_ModoFormulario>(
                        segments: const [
                          ButtonSegment(value: _ModoFormulario.entrar, label: Text('Entrar')),
                          ButtonSegment(value: _ModoFormulario.criarConta, label: Text('Criar conta')),
                        ],
                        selected: {_modo},
                        onSelectionChanged: (novo) => setState(() {
                          _modo = novo.first;
                          _erroFormulario = null;
                          _avisoFormulario = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              enabled: !_enviando,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'E-mail',
                                border: OutlineInputBorder(),
                              ),
                              validator: (valor) {
                                if (valor == null || valor.trim().isEmpty) return 'Digite seu e-mail.';
                                if (!valor.contains('@')) return 'E-mail inválido.';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _senhaController,
                              enabled: !_enviando,
                              obscureText: true,
                              autofillHints: [
                                _modo == _ModoFormulario.entrar
                                    ? AutofillHints.password
                                    : AutofillHints.newPassword,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Senha',
                                border: OutlineInputBorder(),
                              ),
                              validator: (valor) {
                                if (valor == null || valor.isEmpty) return 'Digite sua senha.';
                                if (_modo == _ModoFormulario.criarConta && valor.length < 6) {
                                  return 'Use pelo menos 6 caracteres.';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _enviarFormulario(),
                            ),
                            if (_erroFormulario != null) ...[
                              const SizedBox(height: 12),
                              _caixaMensagem(context, _erroFormulario!, erro: true),
                            ],
                            if (_avisoFormulario != null) ...[
                              const SizedBox(height: 12),
                              _caixaMensagem(context, _avisoFormulario!, erro: false),
                            ],
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _enviando ? null : _enviarFormulario,
                              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                              child: _enviando
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(_modo == _ModoFormulario.entrar ? 'Entrar' : 'Criar conta'),
                            ),
                            if (_modo == _ModoFormulario.entrar) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _enviando ? null : _esqueciSenha,
                                child: const Text('Esqueci minha senha'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _caixaMensagem(BuildContext context, String texto, {required bool erro}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: erro ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: TextStyle(color: erro ? scheme.onErrorContainer : scheme.onSecondaryContainer),
        textAlign: TextAlign.center,
      ),
    );
  }
}
