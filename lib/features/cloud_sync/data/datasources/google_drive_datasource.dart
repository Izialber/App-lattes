import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../domain/entities/cloud_provider.dart';
import '../../domain/repositories/auth_repository.dart';

/// Chamadas REST à Google Drive API v3 (upload resumível via
/// `POST .../upload/drive/v3/files?uploadType=resumable`).
///
/// Autenticação via interceptor (não como parâmetro em cada método,
/// conforme já documentado antes desta implementação): o interceptor chama
/// `AuthRepository.obterTokenValido` — que renova via refresh token se
/// necessário — ANTES de cada request, nunca reage só ao 401 da API (ver
/// docstring de `RenovarToken`). Um `DioException` com `type: cancel` e
/// `error` = a `Failure` original é lançado quando não há token válido,
/// para `CloudStorageRepositoryImpl` traduzir do mesmo jeito que qualquer
/// outro erro de rede.
class GoogleDriveDatasource {
  GoogleDriveDatasource(AuthRepository authRepository, [Dio? dio]) : _dio = dio ?? Dio() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final tokenOuFalha = await authRepository.obterTokenValido(CloudProvider.googleDrive);
          tokenOuFalha.match(
            (falha) => handler.reject(
              DioException(
                requestOptions: options,
                error: falha,
                type: DioExceptionType.cancel,
                message: 'Sessão do Google Drive inválida: ${falha.message}',
              ),
            ),
            (token) {
              options.headers['Authorization'] = 'Bearer ${token.accessToken}';
              handler.next(options);
            },
          );
        },
      ),
    );
  }

  final Dio _dio;

  static const _apiBase = 'https://www.googleapis.com/drive/v3';
  static const _uploadBase = 'https://www.googleapis.com/upload/drive/v3';

  /// Busca a pasta pelo nome (só entre as não-lixeira) e cria se não achar.
  /// Idempotente na prática: duas chamadas concorrentes podem, em teoria,
  /// criar duas pastas com o mesmo nome (a Drive API não tem "create if not
  /// exists" atômico) — risco aceito, já que este app só chama isto uma
  /// sessão de navegador por vez.
  Future<String> criarPastaSeNaoExistir(String nomePasta) async {
    final existente = await _buscarPorNome(
      nomePasta,
      filtroMimeType: "mimeType='application/vnd.google-apps.folder'",
    );
    if (existente != null) return existente;

    final criada = await _dio.post<Map<String, dynamic>>(
      '$_apiBase/files',
      queryParameters: {'fields': 'id'},
      data: {'name': nomePasta, 'mimeType': 'application/vnd.google-apps.folder'},
      options: Options(contentType: 'application/json'),
    );
    return criada.data!['id'] as String;
  }

  /// Busca um ARQUIVO (não pasta) pelo nome — usado para checar se um
  /// certificado já foi sincronizado antes, sem depender só do estado
  /// local. `null` quando nenhum arquivo com esse nome existe no Drive.
  Future<String?> buscarArquivoPorNome(String nomeArquivo) {
    return _buscarPorNome(
      nomeArquivo,
      filtroMimeType: "mimeType!='application/vnd.google-apps.folder'",
    );
  }

  Future<String?> _buscarPorNome(String nome, {required String filtroMimeType}) async {
    final nomeEscapado = nome.replaceAll("'", r"\'");
    final busca = await _dio.get<Map<String, dynamic>>(
      '$_apiBase/files',
      queryParameters: {
        'q': "$filtroMimeType and name='$nomeEscapado' and trashed=false",
        'spaces': 'drive',
        'fields': 'files(id,name)',
      },
    );

    final encontrados = (busca.data?['files'] as List?) ?? const [];
    if (encontrados.isEmpty) return null;
    return (encontrados.first as Map)['id'] as String;
  }

  Future<String> iniciarSessaoUploadResumivel({
    required String pastaId,
    required String nomeArquivo,
    required int tamanhoBytes,
  }) async {
    final resposta = await _dio.post<dynamic>(
      '$_uploadBase/files',
      queryParameters: {'uploadType': 'resumable', 'fields': 'id'},
      data: {
        'name': nomeArquivo,
        'parents': [pastaId],
      },
      options: Options(contentType: 'application/json'),
    );

    final sessionUrl = resposta.headers.value('location');
    if (sessionUrl == null) {
      throw StateError('Google Drive não retornou a URL de sessão de upload resumível.');
    }
    return sessionUrl;
  }

  /// Envia [bytes] a partir de [offset] na sessão resumível. Nesta
  /// implementação, [bytes] é sempre o arquivo completo a partir do byte 0
  /// (PDFs de certificado são pequenos o bastante para caber num único PUT)
  /// — o parâmetro [offset] e o retorno (bytes confirmados pelo servidor)
  /// já seguem o contrato de upload em partes para quando isso for
  /// necessário (arquivos maiores, retomada após 308), sem exigir mudança
  /// de assinatura depois. `idArquivo` só vem preenchido quando o upload
  /// termina (200/201) — a resposta já inclui o `id` do arquivo criado
  /// porque `iniciarSessaoUploadResumivel` pediu `fields=id`.
  Future<({int bytesConfirmados, String? idArquivo})> enviarChunk({
    required String sessionUrl,
    required List<int> bytes,
    required int offset,
  }) async {
    final tamanhoTotal = offset + bytes.length;
    final resposta = await _dio.put<dynamic>(
      sessionUrl,
      data: Uint8List.fromList(bytes),
      options: Options(
        headers: {
          'Content-Range': 'bytes $offset-${tamanhoTotal - 1}/$tamanhoTotal',
          'Content-Length': bytes.length,
        },
        // 308 (Resume Incomplete) é uma resposta VÁLIDA do protocolo de
        // upload resumível do Google — não um erro. Sem isso, Dio lançaria
        // DioException para todo chunk que não fosse o último.
        validateStatus: (status) => status != null && (status == 200 || status == 201 || status == 308),
      ),
    );

    if (resposta.statusCode == 308) {
      final range = resposta.headers.value('range'); // formato "bytes=0-12345"
      final fim = range?.split('-').last;
      final bytesConfirmados = fim != null ? int.tryParse(fim) : null;
      return (bytesConfirmados: (bytesConfirmados ?? offset) + 1, idArquivo: null);
    }

    final idArquivo = resposta.data is Map ? (resposta.data as Map)['id'] as String? : null;
    return (bytesConfirmados: tamanhoTotal, idArquivo: idArquivo);
  }
}
