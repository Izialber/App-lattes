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
    test('salva bytes e metadados, retorna o comprovante', () async {
      final resultado = await repository.anexar(
        entradaId: 'e1',
        categoria: CategoriaEntradaLattes.curso,
        bytes: const [1, 2, 3],
        nomeArquivo: 'diploma.pdf',
        mimeType: 'application/pdf',
      );

      expect(resultado.isRight(), isTrue);
      resultado.match((_) => fail('esperava Right'), (c) {
        expect(c.entradaId, 'e1');
        expect(c.categoria, CategoriaEntradaLattes.curso);
        expect(c.nomeArquivo, 'diploma.pdf');
        expect(c.mimeType, 'application/pdf');
      });
      verify(() => localStore.salvarBytes('e1', const [1, 2, 3])).called(1);
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
      verify(() => localStore.salvarBytes('e1', const [9, 9, 9])).called(1);
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

    test('substitui um comprovante anterior da mesma entrada', () async {
      await repository.anexar(
        entradaId: 'e1',
        categoria: CategoriaEntradaLattes.curso,
        bytes: const [1],
        nomeArquivo: 'antigo.pdf',
        mimeType: 'application/pdf',
      );
      await repository.anexar(
        entradaId: 'e1',
        categoria: CategoriaEntradaLattes.curso,
        bytes: const [2],
        nomeArquivo: 'novo.pdf',
        mimeType: 'application/pdf',
      );

      verify(() => localStore.salvarBytes('e1', const [1])).called(1);
      verify(() => localStore.salvarBytes('e1', const [2])).called(1);
    });
  });

  group('remover', () {
    test('remove do local store', () async {
      when(() => localStore.remover(any())).thenAnswer((_) async {});

      final resultado = await repository.remover('e1');

      expect(resultado.isRight(), isTrue);
      verify(() => localStore.remover('e1')).called(1);
    });

    test('LocalStorageFailure quando o local store lança', () async {
      when(() => localStore.remover(any())).thenThrow(Exception('falha de disco'));

      final resultado = await repository.remover('e1');

      resultado.match(
        (falha) => expect(falha, isA<LocalStorageFailure>()),
        (_) => fail('esperava Left'),
      );
    });
  });

  group('listarTodos', () {
    test('delega para o local store', () async {
      final comprovante = ComprovanteEntrada(
        entradaId: 'e1',
        categoria: CategoriaEntradaLattes.curso,
        nomeArquivo: 'diploma.pdf',
        mimeType: 'application/pdf',
        anexadoEm: DateTime(2026, 1, 1),
      );
      when(() => localStore.listarTodos()).thenReturn({'e1': comprovante});

      final resultado = await repository.listarTodos();

      expect(resultado, {'e1': comprovante});
    });
  });

  group('lerBytes', () {
    test('delega para o local store', () {
      when(() => localStore.lerBytes('e1')).thenReturn(Uint8List.fromList([1, 2, 3]));

      final bytes = repository.lerBytes('e1');

      expect(bytes, [1, 2, 3]);
    });
  });
}
