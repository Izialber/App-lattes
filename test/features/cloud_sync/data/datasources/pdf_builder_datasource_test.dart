import 'package:flutter_test/flutter_test.dart';

import 'package:certificados_lattes/features/cloud_sync/data/datasources/pdf_builder_datasource.dart';

void main() {
  test('PDF de origem passa direto, sem reencapsular', () async {
    final bytesPdf = '%PDF-1.4 conteúdo falso'.codeUnits;
    final builder = PdfBuilderDatasource();

    final resultado = await builder.construirPdf(bytes: bytesPdf, mimeType: 'application/pdf');

    expect(resultado, bytesPdf);
  });
}
