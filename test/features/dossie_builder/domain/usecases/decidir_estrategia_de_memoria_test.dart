import 'package:flutter_test/flutter_test.dart';

import 'package:certificados_lattes/features/dossie_builder/domain/usecases/decidir_estrategia_de_memoria.dart';

/// Testes da lógica pura de decisão entre mesclar direto, mesclar em partes,
/// ou degradar explicitamente — resultado da decisão do usuário de tratar o
/// teto de memória (350MB no iOS, dinâmico no Android via
/// `navigator.deviceMemory`) com processamento em lotes em vez de sempre
/// mandar o usuário para o desktop.
void main() {
  const decidir = DecidirEstrategiaDeMemoria();
  const teto = 100 * 1024 * 1024; // 100MB, valor redondo para os cálculos do teste
  const hintDeLote = 60 * 1024 * 1024; // 60% do teto, mesma proporção do TaskRunner real

  test('lista vazia: estratégia direta (nada para mesclar)', () {
    final plano = decidir(
      tamanhosBytesPorPdf: const [],
      estimatedSafeHeapBytes: teto,
      batchSizeBytesHint: hintDeLote,
    );
    expect(plano.estrategia, EstrategiaMesclagemDossie.direta);
  });

  test('total (com folga) cabe no teto: estratégia direta', () {
    // 3 PDFs de 10MB cada = 30MB brutos; com folga de 1.6x = 48MB, cabe em 100MB.
    final plano = decidir(
      tamanhosBytesPorPdf: List.filled(3, 10 * 1024 * 1024),
      estimatedSafeHeapBytes: teto,
      batchSizeBytesHint: hintDeLote,
    );
    expect(plano.estrategia, EstrategiaMesclagemDossie.direta);
  });

  test('total não cabe, mas cada PDF isolado cabe: estratégia em partes', () {
    // 20 PDFs de 10MB cada = 200MB brutos; com folga = 320MB, não cabe em 100MB.
    // Cada PDF isolado (10MB, folga 16MB) cabe tranquilamente.
    final plano = decidir(
      tamanhosBytesPorPdf: List.filled(20, 10 * 1024 * 1024),
      estimatedSafeHeapBytes: teto,
      batchSizeBytesHint: hintDeLote,
    );
    expect(plano.estrategia, EstrategiaMesclagemDossie.emPartes);
    expect(plano.totalDeLotes, greaterThan(1));
    // Nenhum lote pode, por construção, ultrapassar o hint de tamanho.
    expect(plano.tamanhoDoLote, greaterThan(0));
  });

  test('nem o maior PDF isolado cabe: estratégia inviável no dispositivo', () {
    // Um único PDF de 90MB; com folga de 1.6x = 144MB, não cabe em 100MB.
    final plano = decidir(
      tamanhosBytesPorPdf: const [90 * 1024 * 1024],
      estimatedSafeHeapBytes: teto,
      batchSizeBytesHint: hintDeLote,
    );
    expect(plano.estrategia, EstrategiaMesclagemDossie.inviavelNoDispositivo);
  });

  test('mistura de tamanhos: o maior PDF isolado ainda domina a checagem de viabilidade', () {
    // 5 PDFs pequenos + 1 PDF de 90MB: mesmo o total dando estratégia "em
    // partes" pela soma, o PDF de 90MB isolado inviabiliza qualquer lote.
    final plano = decidir(
      tamanhosBytesPorPdf: [...List.filled(5, 2 * 1024 * 1024), 90 * 1024 * 1024],
      estimatedSafeHeapBytes: teto,
      batchSizeBytesHint: hintDeLote,
    );
    expect(plano.estrategia, EstrategiaMesclagemDossie.inviavelNoDispositivo);
  });

  test('lotes nunca ultrapassam o hint de tamanho por causa da folga', () {
    // 15 PDFs de 8MB: cada um sozinho cabe fácil; testamos que o algoritmo
    // guloso fecha o lote antes de estourar o hint (60MB).
    final plano = decidir(
      tamanhosBytesPorPdf: List.filled(15, 8 * 1024 * 1024),
      estimatedSafeHeapBytes: teto,
      batchSizeBytesHint: hintDeLote,
    );
    expect(plano.estrategia, EstrategiaMesclagemDossie.emPartes);
    // 8MB com folga 1.6x = 12.8MB por PDF; hint de 60MB comporta no máximo
    // 4 PDFs por lote antes de estourar (4 * 12.8MB = 51.2MB; o 5º levaria a
    // 64MB, acima do hint) — ou seja, no máximo 4 por lote.
    expect(plano.tamanhoDoLote, lessThanOrEqualTo(4));
  });
}
