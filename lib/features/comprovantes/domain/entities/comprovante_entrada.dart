import 'package:equatable/equatable.dart';

import 'categoria_entrada_lattes.dart';

enum StatusSincronizacaoComprovante { naoSincronizado, sincronizando, sincronizado, falha }

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
  final StatusSincronizacaoComprovante statusSincronizacao;
  final String? idArquivoCloud; // preenchido só quando sincronizado
  final String? mensagemErroSincronizacao;

  const ComprovanteEntrada({
    required this.id,
    required this.entradaId,
    required this.categoria,
    required this.nomeArquivo,
    required this.mimeType,
    required this.anexadoEm,
    this.statusSincronizacao = StatusSincronizacaoComprovante.naoSincronizado,
    this.idArquivoCloud,
    this.mensagemErroSincronizacao,
  });

  ComprovanteEntrada copyWith({
    StatusSincronizacaoComprovante? statusSincronizacao,
    String? idArquivoCloud,
    String? mensagemErroSincronizacao,
    bool limparMensagemErroSincronizacao = false,
  }) {
    return ComprovanteEntrada(
      id: id,
      entradaId: entradaId,
      categoria: categoria,
      nomeArquivo: nomeArquivo,
      mimeType: mimeType,
      anexadoEm: anexadoEm,
      statusSincronizacao: statusSincronizacao ?? this.statusSincronizacao,
      idArquivoCloud: idArquivoCloud ?? this.idArquivoCloud,
      mensagemErroSincronizacao: limparMensagemErroSincronizacao
          ? null
          : (mensagemErroSincronizacao ?? this.mensagemErroSincronizacao),
    );
  }

  @override
  List<Object?> get props => [
        id,
        entradaId,
        categoria,
        nomeArquivo,
        mimeType,
        anexadoEm,
        statusSincronizacao,
        idArquivoCloud,
        mensagemErroSincronizacao,
      ];
}
