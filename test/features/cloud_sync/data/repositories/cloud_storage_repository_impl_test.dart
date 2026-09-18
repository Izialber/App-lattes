import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:certificados_lattes/core/error/failures.dart';
import 'package:certificados_lattes/features/cloud_sync/data/datasources/google_drive_datasource.dart';
import 'package:certificados_lattes/features/cloud_sync/data/datasources/onedrive_graph_datasource.dart';
import 'package:certificados_lattes/features/cloud_sync/data/local/upload_queue_local_store.dart';
import 'package:certificados_lattes/features/cloud_sync/data/repositories/cloud_storage_repository_impl.dart';
import 'package:certificados_lattes/features/cloud_sync/domain/entities/cloud_provider.dart';
import 'package:certificados_lattes/features/cloud_sync/domain/entities/upload_task.dart';

class MockGoogleDriveDatasource extends Mock implements GoogleDriveDatasource {}

class MockOneDriveGraphDatasource extends Mock implements OneDriveGraphDatasource {}

class MockUploadQueueLocalStore extends Mock implements UploadQueueLocalStore {}

DioException _erroHttp(int statusCode, {dynamic corpo}) {
  final requestOptions = RequestOptions(path: '/qualquer');
  return DioException(
    requestOptions: requestOptions,
    response: Response(requestOptions: requestOptions, statusCode: statusCode, data: corpo),
    message: 'response has a status code of $statusCode',
  );
}

void main() {
  late MockGoogleDriveDatasource googleDrive;
  late MockOneDriveGraphDatasource oneDrive;
  late MockUploadQueueLocalStore localStore;
  late CloudStorageRepositoryImpl repository;

  UploadTask taskBase({
    String id = 'task1',
    CloudProvider provider = CloudProvider.googleDrive,
    String? uploadSessionUrl,
    int bytesEnviados = 0,
    String? mensagemErro,
  }) =>
      UploadTask(
        id: id,
        certificadoId: 'cert1',
        provider: provider,
        nomeArquivoDeterministico: '2024-05-10_curso-x_abcd1234.pdf',
        caminhoPdfLocal: id,
        status: UploadStatus.pendente,
        uploadSessionUrl: uploadSessionUrl,
        bytesEnviados: bytesEnviados,
        mensagemErro: mensagemErro,
      );

  setUp(() {
    googleDrive = MockGoogleDriveDatasource();
    oneDrive = MockOneDriveGraphDatasource();
    localStore = MockUploadQueueLocalStore();
    repository = CloudStorageRepositoryImpl(googleDrive, oneDrive, localStore);

    when(() => localStore.salvar(any())).thenAnswer((_) async {});
  });

  group('garantirPastaDedicada', () {
    test('retorna o id da pasta para o Google Drive', () async {
      when(() => googleDrive.criarPastaSeNaoExistir(any())).thenAnswer((_) async => 'pasta123');

      final resultado = await repository.garantirPastaDedicada(taskBase());

      expect(resultado.isRight(), isTrue);
      resultado.match((_) => fail('esperava Right'), (id) => expect(id, 'pasta123'));
    });

    test('CloudStorageFailure não transitória para OneDrive (fora de escopo)', () async {
      final resultado = await repository.garantirPastaDedicada(
        taskBase(provider: CloudProvider.oneDrive),
      );

      resultado.match(
        (falha) => expect((falha as CloudStorageFailure).isTransient, isFalse),
        (_) => fail('esperava Left'),
      );
      verifyNever(() => oneDrive.criarPastaSeNaoExistir(any()));
    });
  });

  group('enviarArquivo', () {
    test('CloudStorageFailure não transitória quando o PDF local não existe', () async {
      when(() => localStore.lerPdf(any())).thenReturn(null);

      final resultado = await repository.enviarArquivo(taskBase());

      resultado.match(
        (falha) => expect((falha as CloudStorageFailure).isTransient, isFalse),
        (_) => fail('esperava Left'),
      );
    });

    test('envia com sucesso, marca concluído e guarda o id do arquivo no Drive', () async {
      final pdfBytes = Uint8List.fromList([1, 2, 3]);
      when(() => localStore.lerPdf('task1')).thenReturn(pdfBytes);
      when(() => googleDrive.criarPastaSeNaoExistir(any())).thenAnswer((_) async => 'pasta123');
      when(() => googleDrive.iniciarSessaoUploadResumivel(
            pastaId: any(named: 'pastaId'),
            nomeArquivo: any(named: 'nomeArquivo'),
            tamanhoBytes: any(named: 'tamanhoBytes'),
          )).thenAnswer((_) async => 'https://sessao-de-upload');
      when(() => googleDrive.enviarChunk(
            sessionUrl: any(named: 'sessionUrl'),
            bytes: any(named: 'bytes'),
            offset: any(named: 'offset'),
            tamanhoTotalArquivo: any(named: 'tamanhoTotalArquivo'),
          )).thenAnswer((_) async => (bytesConfirmados: 3, idArquivo: 'arquivo123'));

      final resultado = await repository.enviarArquivo(taskBase());

      expect(resultado.isRight(), isTrue);
      resultado.match((_) => fail('esperava Right'), (t) {
        expect(t.status, UploadStatus.concluido);
        expect(t.idArquivoCloud, 'arquivo123');
        expect(t.bytesEnviados, 3);
      });
    });

    test('sucesso limpa mensagemErro de uma tentativa anterior (achado da 2ª revisão)', () async {
      final pdfBytes = Uint8List.fromList([1, 2, 3]);
      when(() => localStore.lerPdf('task1')).thenReturn(pdfBytes);
      when(() => googleDrive.criarPastaSeNaoExistir(any())).thenAnswer((_) async => 'pasta123');
      when(() => googleDrive.iniciarSessaoUploadResumivel(
            pastaId: any(named: 'pastaId'),
            nomeArquivo: any(named: 'nomeArquivo'),
            tamanhoBytes: any(named: 'tamanhoBytes'),
          )).thenAnswer((_) async => 'https://sessao-de-upload');
      when(() => googleDrive.enviarChunk(
            sessionUrl: any(named: 'sessionUrl'),
            bytes: any(named: 'bytes'),
            offset: any(named: 'offset'),
            tamanhoTotalArquivo: any(named: 'tamanhoTotalArquivo'),
          )).thenAnswer((_) async => (bytesConfirmados: 3, idArquivo: 'arquivo123'));

      final resultado = await repository.enviarArquivo(
        taskBase(mensagemErro: 'falha temporária anterior'),
      );

      resultado.match((_) => fail('esperava Right'), (t) => expect(t.mensagemErro, isNull));
    });

    test('retoma sessão já aberta em vez de iniciar uma nova', () async {
      final pdfBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      when(() => localStore.lerPdf('task1')).thenReturn(pdfBytes);
      when(() => googleDrive.criarPastaSeNaoExistir(any())).thenAnswer((_) async => 'pasta123');
      when(() => googleDrive.enviarChunk(
            sessionUrl: any(named: 'sessionUrl'),
            bytes: any(named: 'bytes'),
            offset: any(named: 'offset'),
            tamanhoTotalArquivo: any(named: 'tamanhoTotalArquivo'),
          )).thenAnswer((_) async => (bytesConfirmados: 5, idArquivo: 'arquivo123'));

      final resultado = await repository.enviarArquivo(
        taskBase(uploadSessionUrl: 'https://sessao-existente', bytesEnviados: 2),
      );

      expect(resultado.isRight(), isTrue);
      verifyNever(() => googleDrive.iniciarSessaoUploadResumivel(
            pastaId: any(named: 'pastaId'),
            nomeArquivo: any(named: 'nomeArquivo'),
            tamanhoBytes: any(named: 'tamanhoBytes'),
          ));
      verify(() => googleDrive.enviarChunk(
            sessionUrl: 'https://sessao-existente',
            bytes: pdfBytes.sublist(2),
            offset: 2,
            tamanhoTotalArquivo: 5,
          )).called(1);
    });

    test('envia em múltiplos chunks quando o arquivo excede o tamanho de um chunk', () async {
      // tamanhoDoChunk=4 força 3 chunks para um arquivo de 10 bytes
      // (4+4+2) — exercita o loop de verdade, não só o caminho de 1 chunk.
      repository = CloudStorageRepositoryImpl(
        googleDrive,
        oneDrive,
        localStore,
        tamanhoDoChunk: 4,
      );
      final pdfBytes = Uint8List.fromList(List.generate(10, (i) => i));
      when(() => localStore.lerPdf('task1')).thenReturn(pdfBytes);
      when(() => googleDrive.criarPastaSeNaoExistir(any())).thenAnswer((_) async => 'pasta123');
      when(() => googleDrive.iniciarSessaoUploadResumivel(
            pastaId: any(named: 'pastaId'),
            nomeArquivo: any(named: 'nomeArquivo'),
            tamanhoBytes: any(named: 'tamanhoBytes'),
          )).thenAnswer((_) async => 'https://sessao-de-upload');

      final chunksRecebidos = <List<int>>[];
      when(() => googleDrive.enviarChunk(
            sessionUrl: any(named: 'sessionUrl'),
            bytes: any(named: 'bytes'),
            offset: any(named: 'offset'),
            tamanhoTotalArquivo: any(named: 'tamanhoTotalArquivo'),
          )).thenAnswer((invocation) async {
        final offset = invocation.namedArguments[#offset] as int;
        final bytes = invocation.namedArguments[#bytes] as List<int>;
        chunksRecebidos.add(bytes);
        final fim = offset + bytes.length;
        return (bytesConfirmados: fim, idArquivo: fim >= pdfBytes.length ? 'arquivo123' : null);
      });

      final resultado = await repository.enviarArquivo(taskBase());

      expect(resultado.isRight(), isTrue);
      resultado.match((_) => fail('esperava Right'), (t) {
        expect(t.status, UploadStatus.concluido);
        expect(t.bytesEnviados, 10);
      });
      expect(chunksRecebidos, [
        pdfBytes.sublist(0, 4),
        pdfBytes.sublist(4, 8),
        pdfBytes.sublist(8, 10),
      ]);
    });

    test('garantirPastaDedicada e enviarArquivo compartilham o cache da pasta', () async {
      when(() => localStore.lerPdf(any())).thenReturn(Uint8List.fromList([1, 2, 3]));
      when(() => googleDrive.criarPastaSeNaoExistir(any())).thenAnswer((_) async => 'pasta123');
      when(() => googleDrive.iniciarSessaoUploadResumivel(
            pastaId: any(named: 'pastaId'),
            nomeArquivo: any(named: 'nomeArquivo'),
            tamanhoBytes: any(named: 'tamanhoBytes'),
          )).thenAnswer((_) async => 'https://sessao-de-upload');
      when(() => googleDrive.enviarChunk(
            sessionUrl: any(named: 'sessionUrl'),
            bytes: any(named: 'bytes'),
            offset: any(named: 'offset'),
            tamanhoTotalArquivo: any(named: 'tamanhoTotalArquivo'),
          )).thenAnswer((_) async => (bytesConfirmados: 3, idArquivo: 'arquivo123'));

      await repository.garantirPastaDedicada(taskBase());
      await repository.enviarArquivo(taskBase());
      await repository.enviarArquivo(taskBase(id: 'task2'));

      verify(() => googleDrive.criarPastaSeNaoExistir(any())).called(1);
    });

    test('CloudStorageFailure transitória em erro 500 (fila deve tentar de novo)', () async {
      when(() => localStore.lerPdf(any())).thenReturn(Uint8List.fromList([1]));
      when(() => googleDrive.criarPastaSeNaoExistir(any())).thenThrow(_erroHttp(500));

      final resultado = await repository.enviarArquivo(taskBase());

      resultado.match(
        (falha) => expect((falha as CloudStorageFailure).isTransient, isTrue),
        (_) => fail('esperava Left'),
      );
    });

    test('CloudStorageFailure não transitória em erro 403 (permissão)', () async {
      when(() => localStore.lerPdf(any())).thenReturn(Uint8List.fromList([1]));
      when(() => googleDrive.criarPastaSeNaoExistir(any())).thenThrow(
        _erroHttp(403, corpo: {
          'error': {'message': 'The user does not have sufficient permissions.'},
        }),
      );

      final resultado = await repository.enviarArquivo(taskBase());

      resultado.match(
        (falha) {
          expect((falha as CloudStorageFailure).isTransient, isFalse);
          expect(falha.message, contains('sufficient permissions'));
        },
        (_) => fail('esperava Left'),
      );
    });
  });
}
