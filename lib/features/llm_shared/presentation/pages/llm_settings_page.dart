import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/llm_provider_escolhido.dart';
import '../providers/llm_shared_providers.dart';

/// Tela de configuração BYOK: escolher provedor (Gemini/OpenAI) e colar a
/// própria chave de API. A chave só é salva (`SecureStorageService`,
/// cifrada) DEPOIS de uma chamada mínima de teste confirmar que ela é
/// válida — ver `LlmSettingsController.salvarETestar`.
class LlmSettingsPage extends ConsumerStatefulWidget {
  const LlmSettingsPage({super.key});

  @override
  ConsumerState<LlmSettingsPage> createState() => _LlmSettingsPageState();
}

class _LlmSettingsPageState extends ConsumerState<LlmSettingsPage> {
  final _controladorChave = TextEditingController();

  @override
  void dispose() {
    _controladorChave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(llmSettingsControllerProvider);
    final testando = estado.status == StatusTesteLlm.testando;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar provedor de LLM')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            Text(
              'A extração de dados dos certificados usa a sua própria chave de API '
              '(BYOK). Ela fica cifrada só neste navegador — nenhum servidor do app '
              'chega a vê-la.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            SegmentedButton<LlmProviderEscolhido>(
              segments: const [
                ButtonSegment(
                  value: LlmProviderEscolhido.geminiFlash,
                  label: Text('Gemini Flash'),
                ),
                ButtonSegment(
                  value: LlmProviderEscolhido.gpt4oMini,
                  label: Text('GPT-4o mini'),
                ),
              ],
              selected: {estado.provider},
              onSelectionChanged: testando
                  ? null
                  : (selecionados) => ref
                      .read(llmSettingsControllerProvider.notifier)
                      .selecionarProvedor(selecionados.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controladorChave,
              obscureText: true,
              enabled: !testando,
              decoration: const InputDecoration(
                labelText: 'Chave de API',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (estado.jaConfigurado && estado.status == StatusTesteLlm.ocioso)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('Já existe uma chave salva para este provedor.'),
              ),
            if (estado.status == StatusTesteLlm.falha)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  estado.mensagemErro ?? 'Falha ao validar a chave.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (estado.status == StatusTesteLlm.sucesso)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('Chave salva e validada com sucesso.'),
              ),
            FilledButton(
              onPressed: testando ? null : () => _salvar(context),
              child: testando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar e testar conexão'),
            ),
          ],
        ),
      ),
    );
  }

  void _salvar(BuildContext context) {
    final chave = _controladorChave.text.trim();
    if (chave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cole a chave de API antes de salvar.')),
      );
      return;
    }
    ref.read(llmSettingsControllerProvider.notifier).salvarETestar(chave);
  }
}
