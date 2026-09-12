/// Chamadas REST à Google Drive API v3 (upload resumível via
/// `POST .../upload/drive/v3/files?uploadType=resumable`). Usa Dio com
/// interceptor que injeta o access token via `AuthRepository.obterTokenValido`.
///
/// PENDENTE (fora do escopo do entregável 5): implementação real das
/// chamadas (criar pasta, iniciar sessão resumível, enviar chunk, checar
/// status por Content-Range).
class GoogleDriveDatasource {
  Future<String> criarPastaSeNaoExistir(String nomePasta) {
    throw UnimplementedError('GoogleDriveDatasource.criarPastaSeNaoExistir: pendente');
  }

  Future<String> iniciarSessaoUploadResumivel({
    required String pastaId,
    required String nomeArquivo,
    required int tamanhoBytes,
  }) {
    throw UnimplementedError('GoogleDriveDatasource.iniciarSessaoUploadResumivel: pendente');
  }

  Future<int> enviarChunk({
    required String sessionUrl,
    required List<int> bytes,
    required int offset,
  }) {
    throw UnimplementedError('GoogleDriveDatasource.enviarChunk: pendente');
  }
}
