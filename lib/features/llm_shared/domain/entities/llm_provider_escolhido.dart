/// Provedor de LLM escolhido pelo usuário no fluxo BYOK. Vive em `domain`
/// (não em `data`, onde estava originalmente) porque agora é referenciado
/// pelo contrato de `LlmRepository.testarConexao` — um repositório de
/// domínio não deveria depender de um tipo definido na camada de dados.
enum LlmProviderEscolhido { geminiFlash, gpt4oMini }
