import 'package:equatable/equatable.dart';

import 'cloud_provider.dart';

enum UploadStatus { pendente, emProgresso, concluido, falhaTemporaria, falhaPermanente }

/// Um item da fila offline-first de upload. Persistido em Hive/IndexedDB a
/// cada mudança de status, para que a fila sobreviva a reload de aba e a
/// quedas de conexão em redes 4G instáveis (requisito explícito do módulo 3).
///
/// [referenciaId] é uma chave opaca — a fila nunca interpreta o que ela
/// significa, só carrega de volta pra quem enfileirou (o Módulo 2 antigo
/// usa `CertificadoCapturado.id`; o módulo de comprovantes usa
/// `ComprovanteEntrada.id`). Os dois módulos compartilham a MESMA fila em
/// vez de duplicar toda a lógica de retry/chunking (ver DECISOES.md,
/// "Conectar o Módulo 3 ao módulo de comprovantes").
class UploadTask extends Equatable {
  final String id;
  final String referenciaId;
  final CloudProvider provider;
  final String nomeArquivoDeterministico;
  final String caminhoPdfLocal;
  final UploadStatus status;
  final int tentativas;
  final String? uploadSessionUrl; // sessão de upload resumível da API
  final int bytesEnviados;
  final String? idArquivoCloud; // preenchido só quando status == concluido
  final String? mensagemErro;

  /// Nome de uma subpasta dentro da pasta dedicada do Drive/OneDrive —
  /// `null` mantém o comportamento antigo (tudo solto na pasta raiz). O
  /// módulo de comprovantes preenche com o rótulo da categoria (ex.:
  /// "Formação acadêmica"), pra organizar por seção — ver
  /// `CloudStorageRepositoryImpl._pastaId`.
  final String? subpastaNome;

  const UploadTask({
    required this.id,
    required this.referenciaId,
    required this.provider,
    required this.nomeArquivoDeterministico,
    required this.caminhoPdfLocal,
    required this.status,
    this.tentativas = 0,
    this.uploadSessionUrl,
    this.bytesEnviados = 0,
    this.idArquivoCloud,
    this.mensagemErro,
    this.subpastaNome,
  });

  UploadTask copyWith({
    UploadStatus? status,
    int? tentativas,
    String? uploadSessionUrl,
    int? bytesEnviados,
    String? idArquivoCloud,
    String? mensagemErro,
    bool limparMensagemErro = false,
  }) {
    return UploadTask(
      id: id,
      referenciaId: referenciaId,
      provider: provider,
      nomeArquivoDeterministico: nomeArquivoDeterministico,
      caminhoPdfLocal: caminhoPdfLocal,
      status: status ?? this.status,
      tentativas: tentativas ?? this.tentativas,
      uploadSessionUrl: uploadSessionUrl ?? this.uploadSessionUrl,
      bytesEnviados: bytesEnviados ?? this.bytesEnviados,
      idArquivoCloud: idArquivoCloud ?? this.idArquivoCloud,
      mensagemErro: limparMensagemErro ? null : (mensagemErro ?? this.mensagemErro),
      subpastaNome: subpastaNome,
    );
  }

  @override
  List<Object?> get props => [
        id,
        referenciaId,
        provider,
        nomeArquivoDeterministico,
        caminhoPdfLocal,
        status,
        tentativas,
        uploadSessionUrl,
        bytesEnviados,
        idArquivoCloud,
        mensagemErro,
        subpastaNome,
      ];
}
