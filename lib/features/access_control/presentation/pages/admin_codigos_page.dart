import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/admin_config.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/routing/voltar_app_bar_button.dart';
import '../../domain/entities/codigo_acesso.dart';
import '../providers/codigo_acesso_providers.dart';

final _formatoData = DateFormat('dd/MM/yyyy HH:mm');

/// Gestão de códigos de convite. Gate próprio, INDEPENDENTE do login
/// Google/e-mail-senha do resto do app — precisa especificamente de uma
/// sessão Firebase Auth como [AdminConfig.email], porque só essa sessão dá
/// ao Firestore uma identidade que as regras de segurança confiam (ver
/// DECISOES.md, "Códigos de convite"). A conta admin é criada manualmente
/// no Firebase Console (não pelo formulário de "Criar conta" do app).
class AdminCodigosPage extends ConsumerWidget {
  const AdminCodigosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(firebaseAuthStateProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const VoltarAppBarButton(rotaPai: AppRoutes.importarLattes),
        title: const Text('Códigos de convite'),
      ),
      body: authState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Falha ao checar sessão: $e')),
        data: (user) => user?.email?.toLowerCase() == AdminConfig.email
            ? const _PainelCodigos()
            : const _LoginAdmin(),
      ),
    );
  }
}

class _LoginAdmin extends ConsumerStatefulWidget {
  const _LoginAdmin();

  @override
  ConsumerState<_LoginAdmin> createState() => _LoginAdminState();
}

class _LoginAdminState extends ConsumerState<_LoginAdmin> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() {
      _enviando = true;
      _erro = null;
    });

    try {
      final credencial = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text,
      );
      // Segunda camada de defesa (a de verdade são as regras do Firestore):
      // qualquer conta Firebase válida consegue LOGAR aqui, mas só a do
      // admin deve ver o painel — sai de novo na hora se não bater.
      if (credencial.user?.email?.toLowerCase() != AdminConfig.email) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() {
          _enviando = false;
          _erro = 'Esta conta não tem acesso a esta página.';
        });
        return;
      }
      if (!mounted) return;
      setState(() => _enviando = false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _erro = 'Não foi possível entrar: ${e.message ?? e.code}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.admin_panel_settings_outlined,
                    size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Entrar como administrador',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_erro != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _erro!,
                      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _emailController,
                  enabled: !_enviando,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _senhaController,
                  enabled: !_enviando,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder()),
                  onSubmitted: (_) => _entrar(),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _enviando ? null : _entrar,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: _enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Entrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PainelCodigos extends ConsumerWidget {
  const _PainelCodigos();

  Future<void> _abrirDialogoGerar(BuildContext context, WidgetRef ref) async {
    final controladorRotulo = TextEditingController();
    final rotulo = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gerar novo código'),
        content: TextField(
          controller: controladorRotulo,
          decoration: const InputDecoration(
            labelText: 'Rótulo (opcional)',
            hintText: 'ex.: "para Fulano"',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controladorRotulo.text.trim()),
            child: const Text('Gerar'),
          ),
        ],
      ),
    );
    controladorRotulo.dispose();
    if (rotulo == null) return;
    await ref
        .read(adminCodigosControllerProvider.notifier)
        .gerarCodigo(rotulo: rotulo.isEmpty ? null : rotulo);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(adminCodigosControllerProvider);

    return Column(
      children: [
        if (estado.erro != null)
          MaterialBanner(
            content: Text(estado.erro!),
            leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
            actions: [
              TextButton(
                onPressed: () => ref.read(adminCodigosControllerProvider.notifier).limparErro(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _abrirDialogoGerar(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Gerar código'),
            ),
          ),
        ),
        Expanded(
          child: estado.carregando
              ? const Center(child: CircularProgressIndicator())
              : estado.codigos.isEmpty
                  ? const Center(child: Text('Nenhum código gerado ainda.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: estado.codigos.length,
                      itemBuilder: (context, index) => _linhaCodigo(context, ref, estado.codigos[index]),
                    ),
        ),
      ],
    );
  }

  Widget _linhaCodigo(BuildContext context, WidgetRef ref, CodigoAcesso codigo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          codigo.usado ? Icons.check_circle_outline : Icons.vpn_key_outlined,
          color: codigo.usado
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).hintColor,
        ),
        title: Text(codigo.codigo, style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontFamily: 'monospace',
              letterSpacing: 1.5,
            )),
        subtitle: Text([
          if (codigo.rotulo != null && codigo.rotulo!.isNotEmpty) codigo.rotulo!,
          'Criado em ${_formatoData.format(codigo.criadoEm)}',
          if (codigo.usado)
            'Usado${codigo.usadoPara != null ? ' por ${codigo.usadoPara}' : ''}'
                '${codigo.usadoEm != null ? ' em ${_formatoData.format(codigo.usadoEm!)}' : ''}'
          else
            'Disponível',
        ].join(' · ')),
        trailing: codigo.usado
            ? null
            : IconButton(
                tooltip: 'Revogar código',
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    ref.read(adminCodigosControllerProvider.notifier).revogar(codigo.codigo),
              ),
      ),
    );
  }
}
