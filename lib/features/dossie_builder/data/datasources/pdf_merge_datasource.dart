import 'dart:math';
import 'dart:ui';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../../core/platform/task_runner/task_runner.dart';
import '../../domain/usecases/decidir_estrategia_de_memoria.dart';

/// Um comprovante pronto pra entrar no dossiê: os bytes ORIGINAIS do
/// arquivo anexado (imagem JPEG/PNG já normalizada pelo módulo 2, ou PDF).
class ArquivoParaDossie {
  const ArquivoParaDossie({required this.bytes, required this.mimeType});

  final List<int> bytes;
  final String mimeType;

  bool get ehPdf => mimeType == 'application/pdf';
}

/// Um lote já mesclado na compilação em partes: o PDF intermediário (só as
/// páginas dos comprovantes, sem sumário) e quantas páginas cada item do
/// lote ocupou — o sumário final precisa disso para numerar sem reabrir os
/// arquivos de origem.
class LoteMesclado {
  const LoteMesclado({required this.bytes, required this.paginasPorItem});

  final List<int> bytes;
  final List<int> paginasPorItem;
}

/// Monta o PDF final do dossiê (sumário + as páginas de cada comprovante,
/// em ordem) a partir dos arquivos ORIGINAIS dos comprovantes.
///
/// Usa `syncfusion_flutter_pdf` (já dependência do projeto, pra ler o texto
/// do edital) em vez de `package:pdf`: `package:pdf` só ESCREVE PDF, não
/// importa páginas de um PDF existente — por isso, até 2026-10-24, os
/// comprovantes de origem PDF ficavam fora do dossiê (ver DECISOES.md,
/// "Mesclagem do dossiê"). Com o Syncfusion, cada página de um PDF de
/// origem vira um template desenhado numa página nova do mesmo tamanho, e
/// imagens são desenhadas centralizadas numa página A4.
///
/// TODA a mesclagem passa por [TaskRunner.run] — nunca chamada direta no
/// isolate de UI.
class PdfMergeDatasource {
  final TaskRunner _taskRunner;

  const PdfMergeDatasource(this._taskRunner);

  /// Linhas do sumário por página A4 — com fonte 11 e margem de 40pt,
  /// cabem ~45; 40 deixa folga pro título "Sumário" na primeira página.
  static const _linhasDeSumarioPorPagina = 40;

  /// Mesclagem direta (estratégia [EstrategiaMesclagemDossie.direta]).
  /// [titulosParaSumario] tem um título por item de [arquivosEmOrdem].
  Future<List<int>> mesclarComSumario({
    required List<ArquivoParaDossie> arquivosEmOrdem,
    required List<String> titulosParaSumario,
  }) {
    return _taskRunner.run(
      task: () async => _montarDocumento(arquivosEmOrdem, titulosParaSumario),
      estimatedInputBytes: _somaBytes(arquivosEmOrdem.map((a) => a.bytes)),
      debugLabel: 'mesclar-dossie-direto',
    );
  }

  /// Primeira etapa da estratégia [EstrategiaMesclagemDossie.emPartes]:
  /// junta as páginas de um lote num PDF intermediário. Abre UM arquivo de
  /// origem por vez e o libera logo depois de copiar: a página desenhada como
  /// template continua íntegra depois do `dispose` da origem (verificado com
  /// o edital real em 2026-10-24), então o pico de memória é o lote em
  /// construção mais o maior arquivo, não a soma de todos.
  Future<LoteMesclado> mesclarLote(List<ArquivoParaDossie> arquivosDoLote) {
    return _taskRunner.run(
      task: () async {
        final documento = PdfDocument();
        try {
          final paginasPorItem = <int>[];
          for (final arquivo in arquivosDoLote) {
            paginasPorItem.add(_acrescentar(documento, arquivo));
          }
          return LoteMesclado(bytes: await documento.save(), paginasPorItem: paginasPorItem);
        } finally {
          documento.dispose();
        }
      },
      estimatedInputBytes: _somaBytes(arquivosDoLote.map((a) => a.bytes)),
      debugLabel: 'mesclar-dossie-lote',
    );
  }

  /// Segunda etapa da estratégia em partes: sumário + as páginas de cada
  /// lote, abrindo um PDF intermediário por vez. [titulosParaSumario] tem um
  /// título por item, na mesma ordem dos lotes.
  Future<List<int>> mesclarIntermediariosComSumario({
    required List<LoteMesclado> lotes,
    required List<String> titulosParaSumario,
  }) {
    return _taskRunner.run(
      task: () async {
        final paginasPorItem = [for (final lote in lotes) ...lote.paginasPorItem];
        final documento = PdfDocument();
        try {
          _escreverSumarioNumerado(documento, titulosParaSumario, paginasPorItem);
          for (final lote in lotes) {
            final intermediario = PdfDocument(inputBytes: lote.bytes);
            _copiarPaginasDePdf(documento, intermediario);
            intermediario.dispose();
          }
          return await documento.save();
        } finally {
          documento.dispose();
        }
      },
      estimatedInputBytes: _somaBytes(lotes.map((l) => l.bytes)),
      debugLabel: 'mesclar-dossie-final',
    );
  }

  /// Copia [arquivo] para o fim de [documento] e devolve quantas páginas
  /// ele ocupou.
  int _acrescentar(PdfDocument documento, ArquivoParaDossie arquivo) {
    if (!arquivo.ehPdf) {
      _desenharImagem(documento, arquivo.bytes);
      return 1;
    }
    final origem = PdfDocument(inputBytes: arquivo.bytes);
    try {
      _copiarPaginasDePdf(documento, origem);
      return origem.pages.count;
    } finally {
      origem.dispose();
    }
  }

  /// Heurística de estimativa de bytes de saída de uma mesclagem direta.
  int estimarBytesSaida(List<List<int>> arquivosEmOrdem) {
    return (_somaBytes(arquivosEmOrdem) * 1.6).round();
  }

  int _somaBytes(Iterable<List<int>> listas) =>
      listas.fold<int>(0, (soma, bytes) => soma + bytes.length);

  Future<List<int>> _montarDocumento(
    List<ArquivoParaDossie> arquivos,
    List<String> titulos,
  ) async {
    // Abre cada PDF de origem uma vez só: precisa saber quantas páginas
    // cada comprovante ocupa ANTES de escrever o sumário, pra numerar certo.
    final origens = [
      for (final arquivo in arquivos) arquivo.ehPdf ? PdfDocument(inputBytes: arquivo.bytes) : null,
    ];
    final documento = PdfDocument();
    try {
      final paginasPorItem = [for (final origem in origens) origem?.pages.count ?? 1];
      _escreverSumarioNumerado(documento, titulos, paginasPorItem);

      for (var i = 0; i < arquivos.length; i++) {
        final origem = origens[i];
        if (origem != null) {
          _copiarPaginasDePdf(documento, origem);
        } else {
          _desenharImagem(documento, arquivos[i].bytes);
        }
      }

      return await documento.save();
    } finally {
      documento.dispose();
      for (final origem in origens) {
        origem?.dispose();
      }
    }
  }

  /// Calcula a página inicial de cada item a partir de [paginasPorItem] e
  /// escreve o sumário.
  void _escreverSumarioNumerado(
    PdfDocument documento,
    List<String> titulos,
    List<int> paginasPorItem,
  ) {
    final paginasDeSumario = max(1, (titulos.length / _linhasDeSumarioPorPagina).ceil());
    final primeiraPaginaPorItem = <int>[];
    var proxima = paginasDeSumario + 1;
    for (final paginas in paginasPorItem) {
      primeiraPaginaPorItem.add(proxima);
      proxima += paginas;
    }
    _escreverSumario(documento, titulos, primeiraPaginaPorItem, paginasDeSumario);
  }

  void _escreverSumario(
    PdfDocument documento,
    List<String> titulos,
    List<int> primeiraPaginaPorItem,
    int paginasDeSumario,
  ) {
    final secao = documento.sections!.add()
      ..pageSettings.size = PdfPageSize.a4
      ..pageSettings.margins.all = 40;
    final fonteTitulo = PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold);
    final fonte = PdfStandardFont(PdfFontFamily.helvetica, 11);
    final alinhadoADireita = PdfStringFormat(alignment: PdfTextAlignment.right);

    for (var pagina = 0; pagina < paginasDeSumario; pagina++) {
      final page = secao.pages.add();
      final largura = page.getClientSize().width;
      var y = 0.0;
      if (pagina == 0) {
        page.graphics.drawString('Sumário', fonteTitulo, bounds: Rect.fromLTWH(0, 0, largura, 30));
        y = 40;
      }

      final inicio = pagina * _linhasDeSumarioPorPagina;
      final fim = min(inicio + _linhasDeSumarioPorPagina, titulos.length);
      for (var i = inicio; i < fim; i++) {
        page.graphics.drawString(
          _encurtar(titulos[i]),
          fonte,
          bounds: Rect.fromLTWH(0, y, largura - 40, 16),
        );
        page.graphics.drawString(
          '${primeiraPaginaPorItem[i]}',
          fonte,
          bounds: Rect.fromLTWH(largura - 40, y, 40, 16),
          format: alinhadoADireita,
        );
        y += 18;
      }
    }
  }

  /// Uma seção por página copiada: cada página do PDF de origem mantém o
  /// próprio tamanho e rotação (diploma em paisagem, histórico em retrato).
  void _copiarPaginasDePdf(PdfDocument documento, PdfDocument origem) {
    for (var i = 0; i < origem.pages.count; i++) {
      final paginaOrigem = origem.pages[i];
      final tamanho = paginaOrigem.size;
      // Orientação ANTES do tamanho: o Syncfusion reordena largura/altura
      // conforme a orientação da seção (retrato por padrão) — achado com o
      // diploma real do IFRJ (999x598), que saía em retrato e cortado.
      final secao = documento.sections!.add()
        ..pageSettings.orientation = tamanho.width > tamanho.height
            ? PdfPageOrientation.landscape
            : PdfPageOrientation.portrait
        ..pageSettings.size = tamanho
        ..pageSettings.margins.all = 0
        ..pageSettings.rotate = paginaOrigem.rotation;
      secao.pages.add().graphics.drawPdfTemplate(paginaOrigem.createTemplate(), Offset.zero, tamanho);
    }
  }

  void _desenharImagem(PdfDocument documento, List<int> bytes) {
    final secao = documento.sections!.add()
      ..pageSettings.size = PdfPageSize.a4
      ..pageSettings.margins.all = 0;
    final page = secao.pages.add();
    final area = page.getClientSize();
    final imagem = PdfBitmap(bytes);
    final escala = min(area.width / imagem.width, area.height / imagem.height);
    final largura = imagem.width * escala;
    final altura = imagem.height * escala;
    page.graphics.drawImage(
      imagem,
      Rect.fromLTWH((area.width - largura) / 2, (area.height - altura) / 2, largura, altura),
    );
  }

  /// Títulos muito longos (nome de evento inteiro) estouram a linha do
  /// sumário e encavalariam no número da página. Antes de encurtar, troca
  /// travessões e aspas tipográficas, que a fonte padrão (Helvetica/WinAnsi)
  /// não desenha — sumiam do sumário sem aviso (achado com títulos reais).
  String _encurtar(String titulo) {
    final simples = titulo
        .replaceAll(RegExp('[–—]'), '-')
        .replaceAll(RegExp('[‘’]'), "'")
        .replaceAll(RegExp('[“”]'), '"');
    return simples.length <= 90 ? simples : '${simples.substring(0, 87)}...';
  }
}
