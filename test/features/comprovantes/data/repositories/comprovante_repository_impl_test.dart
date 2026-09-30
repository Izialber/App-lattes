import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:certificados_lattes/core/error/failures.dart';
import 'package:certificados_lattes/core/platform/heic/heic_converter.dart';
import 'package:certificados_lattes/features/comprovantes/data/local/comprovante_local_store.dart';
import 'package:certificados_lattes/features/comprovantes/data/repositories/comprovante_repository_impl.dart';
import 'package:certificados_lattes/features/comprovantes/domain/entities/categoria_entrada_lattes.dart';
import 'package:certificados_lattes/features/comprovantes/domain/entities/comprovante_entrada.dart';

class MockComprovanteLocalStore extends Mock implements ComprovanteLocalStore {}

class MockHeicConverter extends Mock implements HeicConverter {}

void main() {
  late MockComprovanteLocalStore localStore;
  late MockHeicConverter heicConverter;
  late ComprovanteRepositoryImpl repository;

  setUp(() {
    localStore = MockComprovanteLocalStore();
    heicConverter = MockHeicConverter();
    repository = ComprovanteRepositoryImpl(localStore, heicConverter);

    when(() => localStore.salvarBytes(any(), any())).thenAnswer((_) async {});
    when(() => localStore.salvar(any())).thenAnswer((_) async {});
    when(() => heicConverter.pareceHeic(any())).thenReturn(false);
  });

  group('anexar', () {
    test('salva bytes e metadados com um id próprio, retorna o comprovante', () async {
      final resultado = await repository.anexar(
        entradaId: 'e1',
        categoria: CategoriaEntradaLattes.curso,
        bytes: const [1, 2, 3],
        nomeArquivo: 'diploma.pdf',
        mimeType: 'application/pdf',
      );

      expect(resultado.isRight(), isTrue);
      resultado.match((_) => fail('esperava Right'), (c) {
        expect(c.id, isNotEmpty);
        expect(c.entradaId, 'e1');
        expect(c.categoria, CategoriaEntradaLattes.curso);
        expect(c.nomeArquivo, 'diploma.pdf');
        expect(c.mimeType, 'application/pdf');
      });
      verify(() => localStore.salvarBytes(any(), const [1, 2, 3])).called(1);
    });

    test('converte HEIC pra JPEG antes de salvar', () async {
      when(() => heicConverter.pareceHeic(any())).thenReturn(true);
      when(() => heicConverter.converterParaJpeg(any())).thenAnswer(
        (_) async => const ConvertedImage(bytes: [9, 9, 9], mimeType: 'image/jpeg'),
      );

      final resultado = await repository.anexar(
        entradaId: 'e1',
        categoria: CategoriaEntradaLattes.curso,
        bytes: const [1, 2, 3],
        nomeArquivo: 'foto.heic',
        mimeType: 'image/heic',
      );

      resultado.match((_) => fail('esperava Right'), (c) {
        expect(c.mimeType, 'image/jpeg');
        expect(c.nomeArquivo, 'foto.jpg');
      });
      verify(() => localStore.salvarBytes(any(), const [9, 9, 9])).called(1);
    });

    test('CaptureFailure quando a conversão HEIC não é suportada', () async {
      when(() => heicConverter.pareceHeic(any())).thenReturn(true);
      when(() => heicConverter.converterParaJpeg(any()))
          .thenThrow(const HeicConversionUnsupportedException('não suportado'));

      final resultado = await repository.anexar(
        entradaId: 'e1',
        categoria: CategoriaEntradaLattes.curso,
        bytes: const [1, 2, 3],
        nomeArquivo: 'foto.heic',
        mimeType: 'image/heic',
      );

      resultado.match(
        (falha) => expect(falha, isA<CaptureFailure>()),
        (_) => fail('esperava Left'),
      );
      verifyNever(() => localStore.salvarBytes(any(), any()));
    });

    test('anexar duas vezes na mesma entrada NÃO substitui — os dois convivem', () async {
      final primeiro = await repository.anexar(
        entradaId: 'e1',
        categoria: CategoriaEntradaLattes.curso,
        bytes: const [1],
        nomeArquivo: 'diploma.pdf',
        mimeType: 'application/pdf',
      );
      final segundo = await repository.anexar(
        entradaId: 'e1',
        categoria: CategoriaEntradaLattes.curso,
        bytes: const [2],
        nomeArquivo: 'historico.pdf',
        mimeType: 'application/pdf',
      );

      final idPrimeiro = primeiro.getOrElse((_) => fail('esperava Right')).id;
      final idSegundo = segundo.getOrElse((_) => fail('esperava Right')).id;
      expect(idPrimeiro, isNot(idSegundo)); // ids diferentes, nenhum sobrescreve o outro

      verify(() => localStore.salvarBytes(any(), const [1])).called(1);
      verify(() => localStore.salvarBytes(any(), const [2])).called(1);
      verify(() => localStore.salvar(any())).called(2);
    });
  });

  group('remover', () {
    test('remove do local store por id do comprovante', () async {
      when(() => localStore.remover(any())).thenAnswer((_) async {});

      final resultado = await repository.remover('c1');

      expect(resultado.isRight(), isTrue);
      verify(() => localStore.remover('c1')).called(1);
    });

    test('LocalStorageFailure quando o local store lança', () async {
      when(() => localStore.remover(any())).thenThrow(Exception('falha de disco'));

      final resultado = await repository.remover('c1');

      resultado.match(
        (falha) => expect(falha, isA<LocalStorageFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });

  group('listarTodos', () {
    test('delega para o local store, incluindo várias entradas com o mesmo entradaId', () async {
      final comprovantes = [
        ComprovanteEntrada(
          id: 'c1',
          entradaId: 'e1',
          categoria: CategoriaEntradaLattes.curso,
          nomeArquivo: 'diploma.pdf',
          mimeType: 'application/pdf',
          anexadoEm: DateTime(2026, 1, 1),
        ),
        ComprovanteEntrada(
          id: 'c2',
          entradaId: 'e1',
          categoria: CategoriaEntradaLattes.curso,
          nomeArquivo: 'historico.pdf',
          mimeType: 'application/pdf',
          anexadoEm: DateTime(2026, 1, 2),
        ),
      ];
      when(() => localStore.listarTodos()).thenReturn(comprovantes);

      final resultado = await repository.listarTodos();

      expect(resultado, comprovantes);
    });
  });

  group('lerBytes', () {
    test('delega para o local store por id do comprovante', () {
      when(() => localStore.lerBytes('c1')).thenReturn(Uint8List.fromList([1, 2, 3]));

      final bytes = repository.lerBytes('c1');

      expect(bytes, [1, 2, 3]);
    });
  });

  group('atualizarStatusSincronizacao', () {
    ComprovanteEntrada comprovanteBase() => ComprovanteEntrada(
          id: 'c1',
          entradaId: 'e1',
          categoria: CategoriaEntradaLattes.curso,
          nomeArquivo: 'diploma.pdf',
          mimeType: 'application/pdf',
          anexadoEm: DateTime(2026, 1, 1),
        );

    test('grava status e idArquivoCloud em sucesso', () async {
      when(() => localStore.buscar('c1')).thenReturn(comprovanteBase());

      final resultado = await repository.atualizarStatusSincronizacao(
        'c1',
        StatusSincronizacaoComprovante.sincronizado,
        idArquivoCloud: 'drive123',
      );

      expect(resultado.isRight(), isTrue);
      final salvo = verify(() => localStore.salvar(captureAny())).captured.single
          as ComprovanteEntrada;
      expect(salvo.statusSincronizacao, StatusSincronizacaoComprovante.sincronizado);
      expect(salvo.idArquivoCloud, 'drive123');
    });

    test('limpa mensagemErroSincronizacao anterior quando a transição não traz uma', () async {
      final comErroAnterior = comprovanteBase().copyWith(
        statusSincronizacao: StatusSincronizacaoComprovante.falha,
        mensagemErroSincronizacao: 'falha antiga',
      );
      when(() => localStore.buscar('c1')).thenReturn(comErroAnterior);

      await repository.atualizarStatusSincronizacao(
        'c1',
        StatusSincronizacaoComprovante.sincronizado,
      );

      final salvo = verify(() => localStore.salvar(captureAny())).captured.single
          as ComprovanteEntrada;
      expect(salvo.mensagemErroSincronizacao, isNull);
    });

    test('LocalStorageFailure quando o comprovante não existe', () async {
      when(() => localStore.buscar('inexistente')).thenReturn(null);

      final resultado = await repository.atualizarStatusSincronizacao(
        'inexistente',
        StatusSincronizacaoComprovante.sincronizando,
      );

      resultado.match(
        (falha) => expect(falha, isA<LocalStorageFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });
}
