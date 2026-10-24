import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:certificados_lattes/core/platform/task_runner/task_runner.dart';
import 'package:certificados_lattes/features/dossie_builder/data/datasources/pdf_merge_datasource.dart';

class _FakeTaskRunnerPassthrough extends TaskRunner {
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

ArquivoParaDossie _pngValido() {
  final imagem = img.Image(width: 4, height: 4);
  img.fill(imagem, color: img.ColorRgb8(255, 0, 0));
  return ArquivoParaDossie(bytes: img.encodePng(imagem), mimeType: 'image/png');
}

/// PDF de origem com [paginas] páginas, cada uma com o texto "origem N".
Future<ArquivoParaDossie> _pdfDeOrigem(int paginas, {Size? tamanho}) async {
  final documento = PdfDocument();
  if (tamanho != null) {
    documento.pageSettings
      ..orientation =
          tamanho.width > tamanho.height ? PdfPageOrientation.landscape : PdfPageOrientation.portrait
      ..size = tamanho
      ..margins.all = 0;
  }
  for (var i = 1; i <= paginas; i++) {
    documento.pages.add().graphics.drawString(
          'origem $i',
          PdfStandardFont(PdfFontFamily.helvetica, 12),
          bounds: const Rect.fromLTWH(0, 0, 200, 20),
        );
  }
  final bytes = await documento.save();
  documento.dispose();
  return ArquivoParaDossie(bytes: bytes, mimeType: 'application/pdf');
}

void main() {
  final datasource = PdfMergeDatasource(_FakeTaskRunnerPassthrough());

  test('produz um PDF válido (começa com %PDF) com sumário + 1 página por imagem', () async {
    final pdfBytes = await datasource.mesclarComSumario(
      arquivosEmOrdem: [_pngValido(), _pngValido()],
      titulosParaSumario: ['Certificado A', 'Certificado B'],
    );

    final cabecalho = ascii.decode(pdfBytes.take(5).toList(), allowInvalid: true);
    expect(cabecalho, '%PDF-');
    final resultado = PdfDocument(inputBytes: pdfBytes);
    expect(resultado.pages.count, 3);
    resultado.dispose();
  });

  test('copia todas as páginas de um PDF de origem e numera o sumário pelas páginas reais', () async {
    final pdfBytes = await datasource.mesclarComSumario(
      arquivosEmOrdem: [await _pdfDeOrigem(2), _pngValido()],
      titulosParaSumario: ['Diploma (2 páginas)', 'Certificado em imagem'],
    );

    final resultado = PdfDocument(inputBytes: pdfBytes);
    // sumário (1) + PDF de origem (2) + imagem (1)
    expect(resultado.pages.count, 4);

    final extrator = PdfTextExtractor(resultado);
    final sumario = extrator.extractText(startPageIndex: 0, endPageIndex: 0);
    expect(sumario, contains('Sumário'));
    expect(sumario, contains('Diploma (2 páginas)'));
    // diploma começa na página 2; a imagem, depois das 2 páginas dele, na 4
    expect(sumario, matches(RegExp(r'Diploma \(2 páginas\)\s*2')));
    expect(sumario, matches(RegExp(r'Certificado em imagem\s*4')));
    expect(extrator.extractText(startPageIndex: 2, endPageIndex: 2), contains('origem 2'));
    resultado.dispose();
  });

  test('travessão do título vira hífen no sumário em vez de sumir', () async {
    final pdfBytes = await datasource.mesclarComSumario(
      arquivosEmOrdem: [_pngValido()],
      titulosParaSumario: ['Técnico — diploma'],
    );

    final resultado = PdfDocument(inputBytes: pdfBytes);
    final sumario = PdfTextExtractor(resultado).extractText(startPageIndex: 0, endPageIndex: 0);
    expect(sumario, contains('Técnico - diploma'));
    resultado.dispose();
  });

  test('página de origem em paisagem continua em paisagem (diploma real do IFRJ, 999x598)', () async {
    final pdfBytes = await datasource.mesclarComSumario(
      arquivosEmOrdem: [await _pdfDeOrigem(1, tamanho: const Size(999.69, 598.55))],
      titulosParaSumario: ['Diploma em paisagem'],
    );

    final resultado = PdfDocument(inputBytes: pdfBytes);
    final tamanho = resultado.pages[1].size;
    expect(tamanho.width, closeTo(999.69, 0.5));
    expect(tamanho.height, closeTo(598.55, 0.5));
    resultado.dispose();
  });

  test('sumário com mais títulos do que cabem numa página ocupa páginas extras', () async {
    final arquivos = List.generate(45, (_) => _pngValido());
    final pdfBytes = await datasource.mesclarComSumario(
      arquivosEmOrdem: arquivos,
      titulosParaSumario: [for (var i = 1; i <= 45; i++) 'Item $i'],
    );

    final resultado = PdfDocument(inputBytes: pdfBytes);
    expect(resultado.pages.count, 2 + 45);
    final segundaPaginaDoSumario =
        PdfTextExtractor(resultado).extractText(startPageIndex: 1, endPageIndex: 1);
    // Item 41 é o primeiro da 2ª página do sumário; itens começam na página 3
    expect(segundaPaginaDoSumario, matches(RegExp(r'Item 41\s*43')));
    resultado.dispose();
  });

  group('em partes', () {
    test('lotes + intermediários dão as mesmas páginas e numeração que a mesclagem direta', () async {
      final lote1 = await datasource.mesclarLote([await _pdfDeOrigem(3), _pngValido()]);
      final lote2 = await datasource.mesclarLote([await _pdfDeOrigem(2)]);
      expect(lote1.paginasPorItem, [3, 1]);
      expect(lote2.paginasPorItem, [2]);

      final pdfBytes = await datasource.mesclarIntermediariosComSumario(
        lotes: [lote1, lote2],
        titulosParaSumario: ['Histórico', 'Foto', 'Diploma'],
      );

      final resultado = PdfDocument(inputBytes: pdfBytes);
      // sumário (1) + 3 + 1 + 2
      expect(resultado.pages.count, 7);
      final extrator = PdfTextExtractor(resultado);
      final sumario = extrator.extractText(startPageIndex: 0, endPageIndex: 0);
      expect(sumario, matches(RegExp(r'Histórico\s*2')));
      expect(sumario, matches(RegExp(r'Foto\s*5')));
      expect(sumario, matches(RegExp(r'Diploma\s*6')));
      expect(extrator.extractText(startPageIndex: 3, endPageIndex: 3), contains('origem 3'));
      expect(extrator.extractText(startPageIndex: 6, endPageIndex: 6), contains('origem 2'));
      resultado.dispose();
    });

    test('página em paisagem continua em paisagem depois das duas etapas', () async {
      final lote = await datasource.mesclarLote(
        [await _pdfDeOrigem(1, tamanho: const Size(999.69, 598.55))],
      );
      final pdfBytes = await datasource.mesclarIntermediariosComSumario(
        lotes: [lote],
        titulosParaSumario: ['Diploma em paisagem'],
      );

      final resultado = PdfDocument(inputBytes: pdfBytes);
      final tamanho = resultado.pages[1].size;
      expect(tamanho.width, closeTo(999.69, 0.5));
      expect(tamanho.height, closeTo(598.55, 0.5));
      resultado.dispose();
    });
  });

  test('estimarBytesSaida aplica o mesmo fator de folga de DecidirEstrategiaDeMemoria', () {
    final estimativa = datasource.estimarBytesSaida([
      List.filled(100, 0),
      List.filled(200, 0),
    ]);

    expect(estimativa, (300 * 1.6).round());
  });
}
