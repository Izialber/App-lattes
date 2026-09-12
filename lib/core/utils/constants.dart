/// Constantes globais. Nada aqui é segredo (ver RISCOS.md: chave de LLM é
/// BYOK e nunca fica em código-fonte ou build).
class AppConstants {
  AppConstants._();

  static const String appName = 'Certificados Lattes';

  /// Nome da pasta criada no Drive/OneDrive do usuário para os PDFs gerados.
  static const String cloudFolderName = 'Certificados Lattes';

  /// Padrão determinístico de nome de arquivo enviado ao cloud:
  /// {AAAA-MM-DD}_{categoria}_{hashCurto}.pdf
  static const String pdfNamePattern = r'{data}_{categoria}_{hash}.pdf';

  /// Teto de memória estimado (heurística, ver RISCOS.md) usado pelo
  /// TaskRunner web para decidir entre mesclar direto, mesclar em partes, ou
  /// degradar explicitamente. Valores calibrados por decisão do usuário:
  /// - iOS (Safari): valor fixo conservador. Não existe API de memória
  ///   disponível no WebKit (`navigator.deviceMemory` não é suportado), e
  ///   todo navegador em iOS usa o motor WebKit por baixo (inclusive Chrome/
  ///   Firefox para iOS), então o teto vale para "iOS" como um todo, não só
  ///   para o app Safari.
  /// - Android (Chrome/WebView): calculado dinamicamente a partir de
  ///   `navigator.deviceMemory` (Device Memory API, suportada em Chromium),
  ///   ver `TaskRunnerWeb._computeSafeHeapBytes`. Estas constantes definem
  ///   apenas o piso e o teto do cálculo dinâmico.
  /// - Desktop (ou qualquer navegador sem a API de memória disponível):
  ///   valor fixo, usado como teto do cálculo dinâmico também.
  static const int estimatedSafariIosSafeHeapBytes = 350 * 1024 * 1024; // 350MB (decisão do usuário)
  static const int estimatedMinSafeHeapBytes = 220 * 1024 * 1024; // piso p/ Android muito modesto
  static const int estimatedDesktopSafeHeapBytes = 1536 * 1024 * 1024; // ~1.5GB

  /// Fração conservadora da RAM total do aparelho (relatada por
  /// `navigator.deviceMemory`, em GB) que uma ÚNICA operação pesada pode
  /// reivindicar, deixando o restante para o próprio Chrome, a página e
  /// outras abas abertas.
  static const double androidSafeHeapFractionOfDeviceMemory = 0.25;

  /// Intervalo de tentativa de renovação de token antes da expiração real,
  /// para nunca deixar uma chamada em voo com token prestes a expirar.
  static const Duration tokenRefreshMargin = Duration(minutes: 5);
}
