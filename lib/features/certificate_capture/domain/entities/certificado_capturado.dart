import 'package:equatable/equatable.dart';

import 'vinculo_sugerido.dart';

enum StatusCertificado {
  capturado, // imagem obtida, ainda não enviada ao LLM
  extraindoDados, // chamada ao LLM em andamento
  pendenteRevisao, // LLM respondeu; aguardando aprovação humana (módulo 4)
  aprovado,
  enviandoParaCloud,
  sincronizado, // PDF já está no Drive/OneDrive do usuário
  falhaExtracao,
  falhaSincronizacao,
}

/// Um certificado digitalizado, do momento da captura até a sincronização
/// com o cloud do usuário. O ciclo de vida completo é modelado explicitamente
/// em [StatusCertificado] porque o estado precisa sobreviver a reload de aba
/// (persistido via UploadQueueLocalStore) — nunca inferido implicitamente
/// pela presença/ausência de campos.
class CertificadoCapturado extends Equatable {
  final String id;
  final String caminhoImagemLocal; // referência local (blob URL / IndexedDB key)
  final StatusCertificado status;
  final String? tituloExtraido;
  final String? instituicaoExtraida;
  final int? cargaHorariaExtraidaHoras;
  final DateTime? dataExtraida;
  final VinculoSugerido? vinculoSugerido;
  final String? caminhoPdfConvertido;
  final String? idArquivoCloud;
  final String? mensagemErro;

  const CertificadoCapturado({
    required this.id,
    required this.caminhoImagemLocal,
    required this.status,
    this.tituloExtraido,
    this.instituicaoExtraida,
    this.cargaHorariaExtraidaHoras,
    this.dataExtraida,
    this.vinculoSugerido,
    this.caminhoPdfConvertido,
    this.idArquivoCloud,
    this.mensagemErro,
  });

  CertificadoCapturado copyWith({
    StatusCertificado? status,
    String? tituloExtraido,
    String? instituicaoExtraida,
    int? cargaHorariaExtraidaHoras,
    DateTime? dataExtraida,
    VinculoSugerido? vinculoSugerido,
    String? caminhoPdfConvertido,
    String? idArquivoCloud,
    String? mensagemErro,
  }) {
    return CertificadoCapturado(
      id: id,
      caminhoImagemLocal: caminhoImagemLocal,
      status: status ?? this.status,
      tituloExtraido: tituloExtraido ?? this.tituloExtraido,
      instituicaoExtraida: instituicaoExtraida ?? this.instituicaoExtraida,
      cargaHorariaExtraidaHoras: cargaHorariaExtraidaHoras ?? this.cargaHorariaExtraidaHoras,
      dataExtraida: dataExtraida ?? this.dataExtraida,
      vinculoSugerido: vinculoSugerido ?? this.vinculoSugerido,
      caminhoPdfConvertido: caminhoPdfConvertido ?? this.caminhoPdfConvertido,
      idArquivoCloud: idArquivoCloud ?? this.idArquivoCloud,
      mensagemErro: mensagemErro ?? this.mensagemErro,
    );
  }

  @override
  List<Object?> get props => [
        id,
        caminhoImagemLocal,
        status,
        tituloExtraido,
        instituicaoExtraida,
        cargaHorariaExtraidaHoras,
        dataExtraida,
        vinculoSugerido,
        caminhoPdfConvertido,
        idArquivoCloud,
        mensagemErro,
      ];
}
