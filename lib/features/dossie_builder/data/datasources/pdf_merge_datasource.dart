import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../../../../core/platform/task_runner/task_runner.dart';
import '../../domain/usecases/decidir_estrategia_de_memoria.dart';

/// Monta o PDF final do dossiê (sumário + uma página por certificado) a
/// partir das imagens ORIGINAIS dos certificados — não dos PDFs individuais
/// já enviados ao Drive pelo módulo 3. Isso é uma mudança em relação ao
/// contrato originalmente documentado aqui (`pdfsEmOrdem` como PDFs prontos)
/// — ver DECISOES.md, "Mesclagem do dossiê": `package:pdf` é uma biblioteca
/// de ESCRITA de PDF, sem capacidade de importar páginas de um PDF já
/// existente, então "mesclar PDFs prontos" não é possível com as
/// dependências deste projeto. Construir o dossiê direto a partir das
/// imagens (mesma técnica de `PdfBuilderDatasource`, só que N páginas num
/// documento só em vez de N documentos de 1 página) contorna o problema por
/// completo, sem precisar de nenhuma capacidade de "importação" de PDF.
///
/// TODA a mesclagem passa por [TaskRunner.run] — nunca chamada direta no
/// isolate de UI.
class PdfMergeDatasource {
  final TaskRunner _taskRunner;

  const PdfMergeDatasource(this._taskRunner);

  /// Mesclagem direta (estratégia [EstrategiaMesclagemDossie.direta]):
  /// [imagensEmOrdem] são bytes de imagem (JPEG/PNG — o mesmo formato já
  /// normalizado pelo módulo 2), NÃO PDFs. Certificados cuja origem já era
  /// PDF (suportado desde 2026-09-16) não podem passar por aqui — ver
  /// pendência em DECISOES.md; `DossieRepositoryImpl` os exclui antes de
  /// chamar este método.
  Future<List<int>> mesclarComSumario({
    required List<List<int>> imagensEmOrdem,
    required List<String> titulosParaSumario,
  }) {
    return _taskRunner.run(
      task: () async => _montarDocumento(imagensEmOrdem, titulosParaSumario),
      estimatedInputBytes: _somaBytes(imagensEmOrdem),
      debugLabel: 'mesclar-dossie-direto',
    );
  }

  /// PENDENTE: a estratégia [EstrategiaMesclagemDossie.emPartes] depende de
  /// mesclar PDFs INTERMEDIÁRIOS já gerados (não imagens cruas) — o mesmo
  /// problema de "package:pdf não importa PDF existente" descrito na
  /// docstring da classe, mas sem a saída de "construir direto das
  /// imagens" (os intermediários já são PDFs multi-página, não uma lista de
  /// imagens). `DossieRepositoryImpl.compilarDossieFinal` retorna uma
  /// falha clara para este caso em vez de chamar este método.
  Future<List<int>> mesclarLote(List<List<int>> pdfsDoLote) {
    throw UnimplementedError(
      'PdfMergeDatasource.mesclarLote: mesclagem em partes pendente — ver '
      'DECISOES.md, "Mesclagem do dossiê" (package:pdf não importa PDF existente).',
    );
  }

  /// Ver [mesclarLote].
  Future<List<int>> mesclarIntermediariosComSumario({
    required List<List<int>> pdfsIntermediarios,
    required List<String> titulosParaSumario,
  }) {
    throw UnimplementedError(
      'PdfMergeDatasource.mesclarIntermediariosComSumario: mesclagem em partes pendente — '
      'ver DECISOES.md, "Mesclagem do dossiê".',
    );
  }

  /// Heurística de estimativa de bytes de saída de uma mesclagem direta.
  int estimarBytesSaida(List<List<int>> imagensEmOrdem) {
    return (_somaBytes(imagensEmOrdem) * 1.6).round();
  }

  int _somaBytes(List<List<int>> listas) =>
      listas.fold<int>(0, (soma, bytes) => soma + bytes.length);

  Future<List<int>> _montarDocumento(
    List<List<int>> imagensEmOrdem,
    List<String> titulosParaSumario,
  ) async {
    final documento = pw.Document();

    documento.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Sumário', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            for (var i = 0; i < titulosParaSumario.length; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text(titulosParaSumario[i])),
                    // Sumário é a página 1; cada certificado ocupa
                    // exatamente 1 página em ordem — daí o `i + 2`.
                    pw.Text('${i + 2}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    for (final imagem in imagensEmOrdem) {
      documento.addPage(
        pw.Page(
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Center(
            child: pw.Image(pw.MemoryImage(Uint8List.fromList(imagem)), fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    return documento.save();
  }
}
