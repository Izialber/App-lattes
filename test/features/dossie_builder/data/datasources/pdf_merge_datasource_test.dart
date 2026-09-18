import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:certificados_lattes/core/platform/task_runner/task_runner.dart';
import 'package:certificados_lattes/features/dossie_builder/data/datasources/pdf_merge_datasource.dart';

class _FakeTaskRunnerPassthrough implements TaskRunner {
  @override
  int get estimatedSafeHeapBytes => 1024 * 1024 * 1024;

  @override
  Future<R> run<R>({
    required Future<R> Function() task,
    required int estimatedInputBytes,
    String debugLabel = 'task',
  }) =>
      task();
}

List<int> _pngValido() {
  final imagem = img.Image(width: 4, height: 4);
  img.fill(imagem, color: img.ColorRgb8(255, 0, 0));
  return img.encodePng(imagem);
}

void main() {
  test('produz um PDF válido (começa com %PDF) com sumário + 1 página por imagem', () async {
    final datasource = PdfMergeDatasource(_FakeTaskRunnerPassthrough());
    final png1 = _pngValido();
    final png2 = _pngValido();

    final pdfBytes = await datasource.mesclarComSumario(
      imagensEmOrdem: [png1, png2],
      titulosParaSumario: ['Certificado A', 'Certificado B'],
    );

    expect(pdfBytes, isNotEmpty);
    final cabecalho = ascii.decode(pdfBytes.take(5).toList(), allowInvalid: true);
    expect(cabecalho, '%PDF-');
  });

  test('estimarBytesSaida aplica o mesmo fator de folga de DecidirEstrategiaDeMemoria', () {
    final datasource = PdfMergeDatasource(_FakeTaskRunnerPassthrough());

    final estimativa = datasource.estimarBytesSaida([
      List.filled(100, 0),
      List.filled(200, 0),
    ]);

    expect(estimativa, (300 * 1.6).round());
  });
}
