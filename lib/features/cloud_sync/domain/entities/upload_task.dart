import 'package:equatable/equatable.dart';

import 'cloud_provider.dart';

enum UploadStatus { pendente, emProgresso, concluido, falhaTemporaria, falhaPermanente }

/// Um item da fila offline-first de upload. Persistido em Hive/IndexedDB a
/// cada mudança de status, para que a fila sobreviva a reload de aba e a
/// quedas de conexão em redes 4G instáveis (requisito explícito do módulo 3).
class UploadTask extends Equatable {
  final String id;
  final String certificadoId;
  final CloudProvider provider;
  final String nomeArquivoDeterministico;
  final String caminhoPdfLocal;
  final UploadStatus status;
  final int tentativas;
  final String? uploadSessionUrl; // sessão de upload resumível da API
  final int bytesEnviados;
  final String? mensagemErro;

  const UploadTask({
    required this.id,
    required this.certificadoId,
    required this.provider,
    required this.nomeArquivoDeterministico,
    required this.caminhoPdfLocal,
    required this.status,
    this.tentativas = 0,
    this.uploadSessionUrl,
    this.bytesEnviados = 0,
    this.mensagemErro,
  });

  UploadTask copyWith({
    UploadStatus? status,
    int? tentativas,
    String? uploadSessionUrl,
    int? bytesEnviados,
    String? mensagemErro,
  }) {
    return UploadTask(
      id: id,
      certificadoId: certificadoId,
      provider: provider,
      nomeArquivoDeterministico: nomeArquivoDeterministico,
      caminhoPdfLocal: caminhoPdfLocal,
      status: status ?? this.status,
      tentativas: tentativas ?? this.tentativas,
      uploadSessionUrl: uploadSessionUrl ?? this.uploadSessionUrl,
      bytesEnviados: bytesEnviados ?? this.bytesEnviados,
      mensagemErro: mensagemErro ?? this.mensagemErro,
    );
  }

  @override
  List<Object?> get props => [
        id,
        certificadoId,
        provider,
        nomeArquivoDeterministico,
        caminhoPdfLocal,
        status,
        tentativas,
        uploadSessionUrl,
        bytesEnviados,
        mensagemErro,
      ];
}
