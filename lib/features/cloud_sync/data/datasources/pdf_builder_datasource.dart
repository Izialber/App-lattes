import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

/// Converte a imagem de um certificado numa página de PDF única — Drive e
/// OneDrive recebem sempre PDF, nunca a imagem crua (ver ARQUITETURA.md,
/// fluxo "Converter imagem em PDF" do módulo 3). Se a origem já for PDF
/// (módulo 2 aceita PDF desde a rodada de 2026-09-16, ver DECISOES.md),
/// passa direto sem reencapsular.
class PdfBuilderDatasource {
  Future<List<int>> construirPdf({
    required List<int> bytes,
    required String mimeType,
  }) async {
    if (mimeType == 'application/pdf') return bytes;

    final documento = pw.Document();
    final imagem = pw.MemoryImage(Uint8List.fromList(bytes));
    documento.addPage(
      pw.Page(
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Center(child: pw.Image(imagem, fit: pw.BoxFit.contain)),
      ),
    );
    return documento.save();
  }
}
