import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;
import 'package:mocktail/mocktail.dart';

import 'package:certificados_lattes/core/error/failures.dart';
import 'package:certificados_lattes/core/platform/heic/heic_converter.dart';
import 'package:certificados_lattes/core/platform/task_runner/task_runner.dart';
import 'package:certificados_lattes/features/certificate_capture/data/datasources/llm_extraction_datasource.dart';
import 'package:certificados_lattes/features/certificate_capture/data/local/certificate_local_store.dart';
import 'package:certificados_lattes/features/certificate_capture/data/repositories/certificate_repository_impl.dart';
import 'package:certificados_lattes/features/certificate_capture/domain/entities/certificado_capturado.dart';

class MockLlmExtractionDatasource extends Mock implements LlmExtractionDatasource {}

class MockCertificateLocalStore extends Mock implements CertificateLocalStore {}

class MockHeicConverter extends Mock implements HeicConverter {}

/// Fake real (não mock) de propósito: `TaskRunner.run` é genérico
/// (`Future<R> run<R>(...)`), e mockar um método genérico com mocktail exige
/// casar o argumento de tipo em tempo de execução — arriscado demais para
/// testar aqui algo que não é o próprio contrato do TaskRunner. Este fake
/// só executa a task de verdade, sem nenhum chunking (mesmo comportamento
/// observável de `TaskRunnerWeb` para o que este teste verifica).
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
  late MockLlmExtractionDatasource llmDatasource;
  late MockCertificateLocalStore localStore;
  late MockHeicConverter heicConverter;
  late TaskRunner taskRunner;
  late CertificateRepositoryImpl repository;

  CertificadoCapturado certificadoBase({String id = 'c1', String mimeType = 'image/jpeg'}) =>
      CertificadoCapturado(
        id: id,
        caminhoImagemLocal: id,
        mimeType: mimeType,
        status: StatusCertificado.capturado,
      );

  setUp(() {
    llmDatasource = MockLlmExtractionDatasource();
    localStore = MockCertificateLocalStore();
    heicConverter = MockHeicConverter();
    taskRunner = _FakeTaskRunnerPassthrough();
    repository = CertificateRepositoryImpl(llmDatasource, localStore, heicConverter, taskRunner);

    when(() => localStore.salvar(any())).thenAnswer((_) async {});
    when(() => localStore.salvarImagem(any(), any())).thenAnswer((_) async {});
  });

  group('registrarCaptura', () {
    test('persiste bytes e metadados, retorna certificado com status capturado', () async {
      final resultado = await repository.registrarCaptura(
        imagemBytes: const [1, 2, 3],
        mimeType: 'image/jpeg',
      );

      expect(resultado.isRight(), isTrue);
      resultado.match((_) => fail('esperava Right'), (c) {
        expect(c.status, StatusCertificado.capturado);
        expect(c.caminhoImagemLocal, c.id);
        expect(c.mimeType, 'image/jpeg');
      });
      verify(() => localStore.salvarImagem(any(), const [1, 2, 3])).called(1);
      verify(() => localStore.salvar(any())).called(1);
    });

    test('LocalStorageFailure quando salvar a imagem falha', () async {
      when(() => localStore.salvarImagem(any(), any())).thenThrow(Exception('disco cheio'));

      final resultado = await repository.registrarCaptura(
        imagemBytes: const [1, 2, 3],
        mimeType: 'image/jpeg',
      );

      expect(resultado.isLeft(), isTrue);
      resultado.match(
        (falha) => expect(falha, isA<LocalStorageFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });

  group('normalizarFormatoImagem', () {
    test('não faz nada quando a imagem não é HEIC (idempotente)', () async {
      when(() => localStore.buscar('c1')).thenReturn(certificadoBase());
      when(() => localStore.lerImagem('c1')).thenReturn(Uint8List.fromList([1, 2, 3]));
      when(() => heicConverter.pareceHeic(any())).thenReturn(false);

      final resultado = await repository.normalizarFormatoImagem('c1');

      expect(resultado.isRight(), isTrue);
      verifyNever(() => heicConverter.converterParaJpeg(any()));
    });

    test('converte e substitui a imagem quando é HEIC, atualizando o mimeType', () async {
      final bytesHeic = Uint8List.fromList([1, 2, 3]);
      when(() => localStore.buscar('c1'))
          .thenReturn(certificadoBase(mimeType: 'image/heic'));
      when(() => localStore.lerImagem('c1')).thenReturn(bytesHeic);
      when(() => heicConverter.pareceHeic(bytesHeic)).thenReturn(true);
      when(() => heicConverter.converterParaJpeg(bytesHeic)).thenAnswer(
        (_) async => const ConvertedImage(bytes: [9, 9, 9], mimeType: 'image/jpeg'),
      );

      final resultado = await repository.normalizarFormatoImagem('c1');

      expect(resultado.isRight(), isTrue);
      resultado.match(
        (_) => fail('esperava Right'),
        (c) => expect(c.mimeType, 'image/jpeg'),
      );
      verify(() => localStore.salvarImagem('c1', const [9, 9, 9])).called(1);
    });

    test('CaptureFailure quando a conversão HEIC não é suportada', () async {
      final bytesHeic = Uint8List.fromList([1, 2, 3]);
      when(() => localStore.buscar('c1')).thenReturn(certificadoBase());
      when(() => localStore.lerImagem('c1')).thenReturn(bytesHeic);
      when(() => heicConverter.pareceHeic(bytesHeic)).thenReturn(true);
      when(() => heicConverter.converterParaJpeg(bytesHeic)).thenThrow(
        const HeicConversionUnsupportedException('não suportado'),
      );

      final resultado = await repository.normalizarFormatoImagem('c1');

      expect(resultado.isLeft(), isTrue);
      resultado.match(
        (falha) => expect(falha, isA<CaptureFailure>()),
        (_) => fail('esperava Left'),
      );
    });

    test('LocalStorageFailure quando o certificado não existe', () async {
      when(() => localStore.buscar('desconhecido')).thenReturn(null);

      final resultado = await repository.normalizarFormatoImagem('desconhecido');

      expect(resultado.isLeft(), isTrue);
    });
  });

  group('extrairDados', () {
    test('atualiza o certificado com os dados extraídos em caso de sucesso', () async {
      when(() => localStore.buscar('c1')).thenReturn(certificadoBase());
      when(() => localStore.lerImagem('c1')).thenReturn(Uint8List.fromList(List.filled(20, 1)));
      when(() => llmDatasource.extrair(
            imagemBytes: any(named: 'imagemBytes'),
            mimeType: any(named: 'mimeType'),
          )).thenAnswer((_) async => const Right({
            'titulo': 'Curso X',
            'instituicao': 'UFX',
            'cargaHorariaHoras': 40,
            'data': '2024-05-10',
          }));

      final resultado = await repository.extrairDados('c1');

      expect(resultado.isRight(), isTrue);
      resultado.match((_) => fail('esperava Right'), (c) {
        expect(c.status, StatusCertificado.pendenteRevisao);
        expect(c.tituloExtraido, 'Curso X');
        expect(c.instituicaoExtraida, 'UFX');
        expect(c.cargaHorariaExtraidaHoras, 40);
        expect(c.dataExtraida, DateTime.parse('2024-05-10'));
      });
    });

    test('funciona mesmo quando cargaHorariaHoras e data vêm null', () async {
      when(() => localStore.buscar('c1')).thenReturn(certificadoBase());
      when(() => localStore.lerImagem('c1')).thenReturn(Uint8List.fromList(List.filled(20, 1)));
      when(() => llmDatasource.extrair(
            imagemBytes: any(named: 'imagemBytes'),
            mimeType: any(named: 'mimeType'),
          )).thenAnswer(
        (_) async => const Right({'titulo': 'Curso X', 'instituicao': 'UFX'}),
      );

      final resultado = await repository.extrairDados('c1');

      expect(resultado.isRight(), isTrue);
      resultado.match((_) => fail('esperava Right'), (c) {
        expect(c.cargaHorariaExtraidaHoras, isNull);
        expect(c.dataExtraida, isNull);
      });
    });

    test('PDF pula a compressão de imagem e mantém o mimeType application/pdf', () async {
      final bytesPdf = Uint8List.fromList('%PDF-1.4 conteúdo falso'.codeUnits);
      when(() => localStore.buscar('c1'))
          .thenReturn(certificadoBase(mimeType: 'application/pdf'));
      when(() => localStore.lerImagem('c1')).thenReturn(bytesPdf);
      when(() => llmDatasource.extrair(
            imagemBytes: any(named: 'imagemBytes'),
            mimeType: any(named: 'mimeType'),
          )).thenAnswer((_) async => const Right({'titulo': 'Curso X', 'instituicao': 'UFX'}));

      final resultado = await repository.extrairDados('c1');

      expect(resultado.isRight(), isTrue);
      final chamada = verify(() => llmDatasource.extrair(
            imagemBytes: captureAny(named: 'imagemBytes'),
            mimeType: captureAny(named: 'mimeType'),
          )).captured;
      expect(chamada[0], bytesPdf); // bytes do PDF inalterados (sem tentativa de recomprimir)
      expect(chamada[1], 'application/pdf');
    });

    test('marca falhaExtracao e propaga a falha quando o LLM falha', () async {
      when(() => localStore.buscar('c1')).thenReturn(certificadoBase());
      when(() => localStore.lerImagem('c1')).thenReturn(Uint8List.fromList(List.filled(20, 1)));
      when(() => llmDatasource.extrair(
            imagemBytes: any(named: 'imagemBytes'),
            mimeType: any(named: 'mimeType'),
          )).thenAnswer((_) async => const Left(LlmFailure('chave inválida')));

      final resultado = await repository.extrairDados('c1');

      expect(resultado.isLeft(), isTrue);
      final chamadasSalvar = verify(() => localStore.salvar(captureAny())).captured;
      final ultimoSalvo = chamadasSalvar.last as CertificadoCapturado;
      expect(ultimoSalvo.status, StatusCertificado.falhaExtracao);
      expect(ultimoSalvo.mensagemErro, 'chave inválida');
    });

    test('LocalStorageFailure quando o certificado não existe', () async {
      when(() => localStore.buscar('desconhecido')).thenReturn(null);

      final resultado = await repository.extrairDados('desconhecido');

      expect(resultado.isLeft(), isTrue);
      verifyNever(() => llmDatasource.extrair(
            imagemBytes: any(named: 'imagemBytes'),
            mimeType: any(named: 'mimeType'),
          ));
    });
  });

  group('atualizarStatus', () {
    test('atualiza o status do certificado existente', () async {
      when(() => localStore.buscar('c1')).thenReturn(certificadoBase());

      final resultado = await repository.atualizarStatus('c1', StatusCertificado.aprovado);

      expect(resultado.isRight(), isTrue);
      final chamadasSalvar = verify(() => localStore.salvar(captureAny())).captured;
      expect((chamadasSalvar.single as CertificadoCapturado).status, StatusCertificado.aprovado);
    });

    test('LocalStorageFailure quando o certificado não existe', () async {
      when(() => localStore.buscar('desconhecido')).thenReturn(null);

      final resultado =
          await repository.atualizarStatus('desconhecido', StatusCertificado.aprovado);

      expect(resultado.isLeft(), isTrue);
    });

    test('grava mensagemErro quando informado', () async {
      when(() => localStore.buscar('c1')).thenReturn(certificadoBase());

      await repository.atualizarStatus(
        'c1',
        StatusCertificado.falhaSincronizacao,
        mensagemErro: 'falha ao enviar para o Drive',
      );

      final chamadasSalvar = verify(() => localStore.salvar(captureAny())).captured;
      expect(
        (chamadasSalvar.single as CertificadoCapturado).mensagemErro,
        'falha ao enviar para o Drive',
      );
    });
  });

  group('listarTodos', () {
    test('delega para o local store', () async {
      final certificados = [certificadoBase()];
      when(() => localStore.listarTodos()).thenReturn(certificados);

      final resultado = await repository.listarTodos();

      expect(resultado, certificados);
    });
  });
}
