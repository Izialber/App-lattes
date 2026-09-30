import 'package:equatable/equatable.dart';

import 'categoria_entrada_lattes.dart';

/// Um arquivo de comprovação anexado a uma entrada do Lattes (`entradaId`,
/// ver `EntradaLattesRef`/`gerarIdEntrada`). Uma entrada pode ter vários
/// comprovantes (ex.: diploma + histórico escolar para o mesmo curso) — por
/// isso [id] é a chave de persistência (não [entradaId], que se repete entre
/// vários comprovantes da mesma entrada). Os bytes ficam numa box Hive
/// separada (mesmo padrão de `CertificateLocalStore`), não aqui — este é só
/// o metadado.
class ComprovanteEntrada extends Equatable {
  final String id;
  final String entradaId;
  final CategoriaEntradaLattes categoria;
  final String nomeArquivo;
  final String mimeType;
  final DateTime anexadoEm;

  const ComprovanteEntrada({
    required this.id,
    required this.entradaId,
    required this.categoria,
    required this.nomeArquivo,
    required this.mimeType,
    required this.anexadoEm,
  });

  @override
  List<Object?> get props => [id, entradaId, categoria, nomeArquivo, mimeType, anexadoEm];
}
