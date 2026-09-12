/// Chamadas REST ao Microsoft Graph (`/me/drive/items/.../createUploadSession`
/// para upload resumível de grandes arquivos). Espelha a interface de
/// [GoogleDriveDatasource] propositalmente, para que
/// `CloudStorageRepositoryImpl` trate os dois provedores de forma uniforme.
///
/// PENDENTE (fora do escopo do entregável 5): implementação real.
class OneDriveGraphDatasource {
  Future<String> criarPastaSeNaoExistir(String nomePasta) {
    throw UnimplementedError('OneDriveGraphDatasource.criarPastaSeNaoExistir: pendente');
  }

  Future<String> iniciarSessaoUploadResumivel({
    required String pastaId,
    required String nomeArquivo,
    required int tamanhoBytes,
  }) {
    throw UnimplementedError('OneDriveGraphDatasource.iniciarSessaoUploadResumivel: pendente');
  }

  Future<int> enviarChunk({
    required String sessionUrl,
    required List<int> bytes,
    required int offset,
  }) {
    throw UnimplementedError('OneDriveGraphDatasource.enviarChunk: pendente');
  }
}
