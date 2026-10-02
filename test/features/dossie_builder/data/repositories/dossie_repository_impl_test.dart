import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:certificados_lattes/core/error/failures.dart';
import 'package:certificados_lattes/core/platform/task_runner/task_runner.dart';
import 'package:certificados_lattes/features/comprovantes/data/local/comprovante_local_store.dart';
import 'package:certificados_lattes/features/comprovantes/domain/entities/categoria_entrada_lattes.dart';
import 'package:certificados_lattes/features/comprovantes/domain/entities/comprovante_entrada.dart';
import 'package:certificados_lattes/features/comprovantes/domain/entities/entrada_lattes_ref.dart';
import 'package:certificados_lattes/features/dossie_builder/data/datasources/llm_edital_datasource.dart';
import 'package:certificados_lattes/features/dossie_builder/data/datasources/pdf_merge_datasource.dart';
import 'package:certificados_lattes/features/dossie_builder/data/local/dossie_local_store.dart';
import 'package:certificados_lattes/features/dossie_builder/data/repositories/dossie_repository_impl.dart';
import 'package:certificados_lattes/features/dossie_builder/domain/entities/criterio_pontuacao.dart';
import 'package:certificados_lattes/features/dossie_builder/domain/entities/dossie.dart';
import 'package:certificados_lattes/features/dossie_builder/domain/entities/edital.dart';
import 'package:certificados_lattes/features/dossie_builder/domain/entities/vinculo_aprovado.dart';

class MockLlmEditalDatasource extends Mock implements LlmEditalDatasource {}

class MockPdfMergeDatasource extends Mock implements PdfMergeDatasource {}

class MockDossieLocalStore extends Mock implements DossieLocalStore {}

class MockComprovanteLocalStore extends Mock implements ComprovanteLocalStore {}

/// Passthrough real (não mock) — mesmo motivo já documentado em
/// `certificate_repository_impl_test.dart`: `TaskRunner.run` é genérico, e
/// mockar método genérico com mocktail é arriscado para algo que não é o
/// próprio contrato do TaskRunner.
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

void main() {
  late MockLlmEditalDatasource llmEdital;
  late MockPdfMergeDatasource pdfMerge;
  late TaskRunner taskRunner;
  late MockDossieLocalStore localStore;
  late MockComprovanteLocalStore comprovanteLocalStore;
  late DossieRepositoryImpl repository;

  setUp(() {
    llmEdital = MockLlmEditalDatasource();
    pdfMerge = MockPdfMergeDatasource();
    taskRunner = _FakeTaskRunnerPassthrough();
    localStore = MockDossieLocalStore();
    comprovanteLocalStore = MockComprovanteLocalStore();
    repository = DossieRepositoryImpl(
      llmEdital,
      pdfMerge,
      taskRunner,
      localStore,
      comprovanteLocalStore,
    );

    when(() => localStore.salvarEdital(any())).thenAnswer((_) async {});
    when(() => localStore.salvarDossie(any())).thenAnswer((_) async {});
  });

  group('extrairCriterios', () {
    test('monta o Edital a partir do JSON do LLM, com id gerado por critério', () async {
      when(() => llmEdital.extrairCriterios(any())).thenAnswer((_) async => {
            'orgaoOuBanca': 'Banca X',
            'criterios': [
              {'descricao': 'Doutorado', 'pontosPorUnidade': 10.0, 'limiteMaximoUnidades': 1},
              {'descricao': 'Curso de capacitação', 'pontosPorUnidade': null, 'limiteMaximoUnidades': null},
            ],
          });

      final resultado = await repository.extrairCriterios(
        editalId: 'edital1',
        nomeArquivoOriginal: 'edital.pdf',
        editalPdfBytes: const [1, 2, 3],
      );

      expect(resultado.isRight(), isTrue);
      resultado.match((_) => fail('esperava Right'), (edital) {
        expect(edital.id, 'edital1');
        expect(edital.nomeArquivoOriginal, 'edital.pdf');
        expect(edital.orgaoOuBanca, 'Banca X');
        expect(edital.criterios, hasLength(2));
        expect(edital.criterios[0].descricao, 'Doutorado');
        expect(edital.criterios[0].pontosPorUnidade, 10.0);
        expect(edital.criterios[0].limiteMaximoUnidades, 1);
        expect(edital.criterios[1].pontosPorUnidade, isNull);
        // ids gerados e distintos entre os dois critérios
        expect(edital.criterios[0].id, isNot(edital.criterios[1].id));
      });
      verify(() => localStore.salvarEdital(any())).called(1);
    });

    test('DossieFailure quando o datasource lança (ex.: PDF sem texto)', () async {
      when(() => llmEdital.extrairCriterios(any()))
          .thenThrow(StateError('sem texto legível'));

      final resultado = await repository.extrairCriterios(
        editalId: 'edital1',
        nomeArquivoOriginal: 'edital.pdf',
        editalPdfBytes: const [1, 2, 3],
      );

      expect(resultado.isLeft(), isTrue);
      resultado.match((falha) => expect(falha, isA<DossieFailure>()), (_) => fail('esperava Left'));
      verifyNever(() => localStore.salvarEdital(any()));
    });

    test('ignora itens malformados de "criterios" e coage tipos inesperados', () async {
      // Achado da revisão de código: um `as Map`/`as String?` direto num
      // item malformado derrubava a extração do edital INTEIRO por causa
      // de UM item ruim, em vez de só ignorar aquele item.
      when(() => llmEdital.extrairCriterios(any())).thenAnswer((_) async => {
            'orgaoOuBanca': 42, // tipo errado (número em vez de string)
            'criterios': [
              'isso não é um objeto', // item malformado — deve ser ignorado
              {
                'descricao': 'Doutorado',
                'pontosPorUnidade': '10,5', // string com vírgula decimal
                'limiteMaximoUnidades': '1 título', // string com texto junto
              },
            ],
          });

      final resultado = await repository.extrairCriterios(
        editalId: 'edital1',
        nomeArquivoOriginal: 'edital.pdf',
        editalPdfBytes: const [1, 2, 3],
      );

      expect(resultado.isRight(), isTrue);
      resultado.match((_) => fail('esperava Right'), (edital) {
        expect(edital.orgaoOuBanca, '42');
        expect(edital.criterios, hasLength(1));
        expect(edital.criterios.single.descricao, 'Doutorado');
        expect(edital.criterios.single.pontosPorUnidade, 10.5);
        expect(edital.criterios.single.limiteMaximoUnidades, 1);
      });
    });
  });

  group('sugerirVinculos', () {
    ComprovanteEntrada comprovante({String id = 'c1', String entradaId = 'e1'}) =>
        ComprovanteEntrada(
          id: id,
          entradaId: entradaId,
          categoria: CategoriaEntradaLattes.curso,
          nomeArquivo: 'arquivo.jpg',
          mimeType: 'image/jpeg',
          anexadoEm: DateTime(2026),
          statusSincronizacao: StatusSincronizacaoComprovante.sincronizado,
        );

    EntradaLattesRef entrada({String id = 'e1', String titulo = '', String subtitulo = ''}) =>
        EntradaLattesRef(
          id: id,
          categoria: CategoriaEntradaLattes.curso,
          titulo: titulo,
          subtitulo: subtitulo,
        );

    test('sugere o critério com maior sobreposição de palavras', () async {
      final edital = Edital(
        id: 'edital1',
        nomeArquivoOriginal: 'edital.pdf',
        criterios: const [
          CriterioPontuacao(id: 'crit-doutorado', descricao: 'Curso de doutorado concluído'),
          CriterioPontuacao(id: 'crit-capacitacao', descricao: 'Curso de capacitação mínimo 20h'),
        ],
      );
      final comp = comprovante();
      final entradaDoComp = entrada(titulo: 'Curso de capacitação em gestão pública');

      final resultado = await repository.sugerirVinculos(
        edital: edital,
        comprovantesSincronizados: [comp],
        entradas: [entradaDoComp],
      );

      expect(resultado.isRight(), isTrue);
      resultado.match((_) => fail('esperava Right'), (sugestoes) {
        expect(sugestoes, hasLength(1));
        expect(sugestoes.single.comprovanteId, 'c1');
        expect(sugestoes.single.criterioId, 'crit-capacitacao');
      });
    });

    test('não sugere nada quando não há sobreposição relevante', () async {
      final edital = Edital(
        id: 'edital1',
        nomeArquivoOriginal: 'edital.pdf',
        criterios: const [
          CriterioPontuacao(id: 'crit-doutorado', descricao: 'Curso de doutorado concluído'),
        ],
      );
      final comp = comprovante();
      final entradaDoComp = entrada(titulo: 'Workshop de fotografia amadora');

      final resultado = await repository.sugerirVinculos(
        edital: edital,
        comprovantesSincronizados: [comp],
        entradas: [entradaDoComp],
      );

      resultado.match((_) => fail('esperava Right'), (sugestoes) => expect(sugestoes, isEmpty));
    });

    test('lista vazia de critérios não gera sugestão nem lança', () async {
      final edital = Edital(id: 'edital1', nomeArquivoOriginal: 'edital.pdf');
      final comp = comprovante();
      final entradaDoComp = entrada(titulo: 'Qualquer coisa');

      final resultado = await repository.sugerirVinculos(
        edital: edital,
        comprovantesSincronizados: [comp],
        entradas: [entradaDoComp],
      );

      resultado.match((_) => fail('esperava Right'), (sugestoes) => expect(sugestoes, isEmpty));
    });

    test('comprovante órfão (sem entrada correspondente) usa o nome do arquivo no match',
        () async {
      final edital = Edital(
        id: 'edital1',
        nomeArquivoOriginal: 'edital.pdf',
        criterios: const [
          CriterioPontuacao(id: 'crit-diploma', descricao: 'Diploma de graduação'),
        ],
      );
      final comp = ComprovanteEntrada(
        id: 'c1',
        entradaId: 'entrada-removida',
        categoria: CategoriaEntradaLattes.curso,
        nomeArquivo: 'diploma de graduacao.pdf',
        mimeType: 'application/pdf',
        anexadoEm: DateTime(2026),
        statusSincronizacao: StatusSincronizacaoComprovante.sincronizado,
      );

      final resultado = await repository.sugerirVinculos(
        edital: edital,
        comprovantesSincronizados: [comp],
        entradas: const [], // entrada original não existe mais (reimportação)
      );

      resultado.match((_) => fail('esperava Right'), (sugestoes) {
        expect(sugestoes, hasLength(1));
        expect(sugestoes.single.criterioId, 'crit-diploma');
      });
    });
  });

  group('registrarDecisaoVinculo', () {
    test('adiciona a decisão à lista de vínculos revisados do dossiê', () async {
      final dossieAtual = const Dossie(
        id: 'dossie1',
        editalId: 'edital1',
        status: StatusDossie.aguardandoRevisaoHumana,
      );
      when(() => localStore.buscarDossie('dossie1')).thenReturn(dossieAtual);

      final resultado = await repository.registrarDecisaoVinculo(
        dossieId: 'dossie1',
        decisao: const VinculoAprovado(
          comprovanteId: 'c1',
          criterioId: 'crit1',
          decisao: DecisaoVinculo.aprovado,
        ),
      );

      expect(resultado.isRight(), isTrue);
      resultado.match((_) => fail('esperava Right'), (d) {
        expect(d.vinculosRevisados, hasLength(1));
        expect(d.vinculosRevisados.single.decisao, DecisaoVinculo.aprovado);
      });
    });

    test('substitui decisão anterior para o mesmo par comprovante/critério', () async {
      final dossieAtual = Dossie(
        id: 'dossie1',
        editalId: 'edital1',
        status: StatusDossie.aguardandoRevisaoHumana,
        vinculosRevisados: const [
          VinculoAprovado(comprovanteId: 'c1', criterioId: 'crit1', decisao: DecisaoVinculo.excluido),
        ],
      );
      when(() => localStore.buscarDossie('dossie1')).thenReturn(dossieAtual);

      final resultado = await repository.registrarDecisaoVinculo(
        dossieId: 'dossie1',
        decisao: const VinculoAprovado(
          comprovanteId: 'c1',
          criterioId: 'crit1',
          decisao: DecisaoVinculo.aprovado,
        ),
      );

      resultado.match((_) => fail('esperava Right'), (d) {
        expect(d.vinculosRevisados, hasLength(1));
        expect(d.vinculosRevisados.single.decisao, DecisaoVinculo.aprovado);
      });
    });

    test('DossieFailure quando o dossiê não existe', () async {
      when(() => localStore.buscarDossie('desconhecido')).thenReturn(null);

      final resultado = await repository.registrarDecisaoVinculo(
        dossieId: 'desconhecido',
        decisao: const VinculoAprovado(
          comprovanteId: 'c1',
          criterioId: 'crit1',
          decisao: DecisaoVinculo.aprovado,
        ),
      );

      expect(resultado.isLeft(), isTrue);
    });
  });

  group('compilarDossieFinal', () {
    setUp(() {
      when(() => localStore.salvarPdfFinal(any(), any())).thenAnswer((_) async {});
    });

    Dossie dossieComAprovado({String comprovanteId = 'c1'}) => Dossie(
          id: 'dossie1',
          editalId: 'edital1',
          status: StatusDossie.aguardandoRevisaoHumana,
          vinculosRevisados: [
            VinculoAprovado(
              comprovanteId: comprovanteId,
              criterioId: 'crit1',
              decisao: DecisaoVinculo.aprovado,
            ),
          ],
        );

    ComprovanteEntrada comprovanteImagem(String id, {String entradaId = 'e1'}) =>
        ComprovanteEntrada(
          id: id,
          entradaId: entradaId,
          categoria: CategoriaEntradaLattes.curso,
          nomeArquivo: '$id.jpg',
          mimeType: 'image/jpeg',
          anexadoEm: DateTime(2026),
          statusSincronizacao: StatusSincronizacaoComprovante.sincronizado,
        );

    final entradaCursoX = EntradaLattesRef(
      id: 'e1',
      categoria: CategoriaEntradaLattes.curso,
      titulo: 'Curso X',
      subtitulo: '',
    );

    test('DossieFailure quando não há nenhum vínculo aprovado', () async {
      final dossie = const Dossie(
        id: 'dossie1',
        editalId: 'edital1',
        status: StatusDossie.aguardandoRevisaoHumana,
      );
      when(() => localStore.buscarDossie('dossie1')).thenReturn(dossie);

      final resultado = await repository.compilarDossieFinal('dossie1', entradas: const []);

      resultado.match((falha) => expect(falha, isA<DossieFailure>()), (_) => fail('esperava Left'));
      verifyNever(() => pdfMerge.mesclarComSumario(
            imagensEmOrdem: any(named: 'imagensEmOrdem'),
            titulosParaSumario: any(named: 'titulosParaSumario'),
          ));
    });

    test('mescla com sucesso e marca o dossiê como compilado', () async {
      when(() => localStore.buscarDossie('dossie1')).thenReturn(dossieComAprovado());
      when(() => comprovanteLocalStore.buscar('c1')).thenReturn(comprovanteImagem('c1'));
      when(() => comprovanteLocalStore.lerBytes('c1'))
          .thenReturn(Uint8List.fromList([1, 2, 3]));
      when(() => pdfMerge.mesclarComSumario(
            imagensEmOrdem: any(named: 'imagensEmOrdem'),
            titulosParaSumario: any(named: 'titulosParaSumario'),
          )).thenAnswer((_) async => [1, 2, 3, 4]);

      final resultado =
          await repository.compilarDossieFinal('dossie1', entradas: [entradaCursoX]);

      expect(resultado.isRight(), isTrue);
      resultado.match((_) => fail('esperava Right'), (d) {
        expect(d.status, StatusDossie.compilado);
        expect(d.caminhoPdfFinal, 'dossie1');
        expect(d.notaCompilacao, isNull); // nenhum PDF excluído, nada a avisar
      });
      verify(() => localStore.salvarPdfFinal('dossie1', [1, 2, 3, 4])).called(1);
    });

    test('exclui comprovantes de origem PDF e usa só os de imagem', () async {
      final dossie = Dossie(
        id: 'dossie1',
        editalId: 'edital1',
        status: StatusDossie.aguardandoRevisaoHumana,
        vinculosRevisados: const [
          VinculoAprovado(comprovanteId: 'c1', criterioId: 'crit1', decisao: DecisaoVinculo.aprovado),
          VinculoAprovado(comprovanteId: 'c2', criterioId: 'crit1', decisao: DecisaoVinculo.aprovado),
        ],
      );
      when(() => localStore.buscarDossie('dossie1')).thenReturn(dossie);
      when(() => comprovanteLocalStore.buscar('c1')).thenReturn(comprovanteImagem('c1'));
      when(() => comprovanteLocalStore.lerBytes('c1'))
          .thenReturn(Uint8List.fromList([1, 2, 3]));
      when(() => comprovanteLocalStore.buscar('c2')).thenReturn(
        ComprovanteEntrada(
          id: 'c2',
          entradaId: 'e1',
          categoria: CategoriaEntradaLattes.curso,
          nomeArquivo: 'certificado.pdf',
          mimeType: 'application/pdf',
          anexadoEm: DateTime(2026),
          statusSincronizacao: StatusSincronizacaoComprovante.sincronizado,
        ),
      );
      when(() => comprovanteLocalStore.lerBytes('c2'))
          .thenReturn(Uint8List.fromList([9, 9, 9]));
      when(() => pdfMerge.mesclarComSumario(
            imagensEmOrdem: any(named: 'imagensEmOrdem'),
            titulosParaSumario: any(named: 'titulosParaSumario'),
          )).thenAnswer((_) async => [1, 2, 3, 4]);

      final resultado =
          await repository.compilarDossieFinal('dossie1', entradas: [entradaCursoX]);

      expect(resultado.isRight(), isTrue);
      final chamada = verify(() => pdfMerge.mesclarComSumario(
            imagensEmOrdem: captureAny(named: 'imagensEmOrdem'),
            titulosParaSumario: captureAny(named: 'titulosParaSumario'),
          )).captured;
      final imagens = chamada[0] as List<List<int>>;
      expect(imagens, hasLength(1)); // só o comprovante de imagem (c1), não o de PDF (c2)
      resultado.match((_) => fail('esperava Right'), (d) {
        // achado da 2ª revisão de código: o resultado precisa avisar quantos
        // comprovantes ficaram fora, não só o checklist antes de compilar.
        expect(d.notaCompilacao, contains('1 comprovante'));
        expect(d.mensagemDegradacao, isNull); // não é degradação por memória
      });
    });

    test('DossieFailure quando todos os aprovados são PDF de origem', () async {
      when(() => localStore.buscarDossie('dossie1')).thenReturn(dossieComAprovado());
      when(() => comprovanteLocalStore.buscar('c1')).thenReturn(
        ComprovanteEntrada(
          id: 'c1',
          entradaId: 'e1',
          categoria: CategoriaEntradaLattes.curso,
          nomeArquivo: 'certificado.pdf',
          mimeType: 'application/pdf',
          anexadoEm: DateTime(2026),
          statusSincronizacao: StatusSincronizacaoComprovante.sincronizado,
        ),
      );
      when(() => comprovanteLocalStore.lerBytes('c1'))
          .thenReturn(Uint8List.fromList([1, 2, 3]));

      final resultado =
          await repository.compilarDossieFinal('dossie1', entradas: [entradaCursoX]);

      resultado.match((falha) => expect(falha, isA<DossieFailure>()), (_) => fail('esperava Left'));
    });

    test('comprovante órfão usa o nome do arquivo como título no sumário', () async {
      when(() => localStore.buscarDossie('dossie1')).thenReturn(dossieComAprovado());
      when(() => comprovanteLocalStore.buscar('c1')).thenReturn(
        comprovanteImagem('c1', entradaId: 'entrada-removida'),
      );
      when(() => comprovanteLocalStore.lerBytes('c1'))
          .thenReturn(Uint8List.fromList([1, 2, 3]));
      when(() => pdfMerge.mesclarComSumario(
            imagensEmOrdem: any(named: 'imagensEmOrdem'),
            titulosParaSumario: any(named: 'titulosParaSumario'),
          )).thenAnswer((_) async => [1, 2, 3, 4]);

      // `entradas` não inclui a entrada do comprovante — simula reimportação
      // do Lattes que removeu/alterou o item original (ver DECISOES.md).
      final resultado = await repository.compilarDossieFinal('dossie1', entradas: const []);

      expect(resultado.isRight(), isTrue);
      final chamada = verify(() => pdfMerge.mesclarComSumario(
            imagensEmOrdem: any(named: 'imagensEmOrdem'),
            titulosParaSumario: captureAny(named: 'titulosParaSumario'),
          )).captured;
      expect(chamada.single, ['c1.jpg']); // nome do arquivo, não um título vazio/null
    });
  });
}
