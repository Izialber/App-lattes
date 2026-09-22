import 'package:equatable/equatable.dart';

import 'categoria_entrada_lattes.dart';

/// Registro de que uma entrada do Lattes (`entradaId`, ver
/// `EntradaLattesRef`/`gerarIdEntrada`) já tem um arquivo de comprovação
/// anexado. Os bytes ficam numa box Hive separada (mesmo padrão de
/// `CertificateLocalStore`), não aqui — este é só o metadado.
class ComprovanteEntrada extends Equatable {
  final String entradaId;
  final CategoriaEntradaLattes categoria;
  final String nomeArquivo;
  final String mimeType;
  final DateTime anexadoEm;

  const ComprovanteEntrada({
    required this.entradaId,
    required this.categoria,
    required this.nomeArquivo,
    required this.mimeType,
    required this.anexadoEm,
  });

  @override
  List<Object?> get props => [entradaId, categoria, nomeArquivo, mimeType, anexadoEm];
}
