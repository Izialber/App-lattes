import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';

import '../../domain/entities/certificado_capturado.dart';
import '../../domain/entities/vinculo_sugerido.dart';

/// Persistência do módulo 2 em Hive (IndexedDB no web) — metadados e bytes
/// da imagem em boxes separadas, para `listarTodos` (usado pela tela de
/// lista) não precisar carregar os bytes de TODOS os certificados na
/// memória só para mostrar status. Todo método grava de forma síncrona com
/// a mudança de estado do use case correspondente — o estado nunca deve
/// existir só em memória, senão um reload de aba (comum no Safari iOS sob
/// pressão de memória) perde o progresso do usuário, mesmo requisito
/// documentado para `UploadQueueLocalStore`.
///
/// As boxes precisam estar abertas (`Hive.openBox`) ANTES de qualquer
/// método desta classe ser chamado — feito em `core/di/bootstrap.dart`,
/// executado em `main.dart` antes do primeiro frame.
class CertificateLocalStore {
  const CertificateLocalStore();

  static const metadataBoxName = 'certificate_capture_metadata';
  static const imagesBoxName = 'certificate_capture_images';

  Box<Map> get _metadata => Hive.box<Map>(metadataBoxName);
  Box<Uint8List> get _imagens => Hive.box<Uint8List>(imagesBoxName);

  Future<void> salvarImagem(String certificadoId, List<int> bytes) {
    return _imagens.put(certificadoId, Uint8List.fromList(bytes));
  }

  Uint8List? lerImagem(String certificadoId) => _imagens.get(certificadoId);

  Future<void> salvar(CertificadoCapturado certificado) {
    return _metadata.put(certificado.id, _paraMapa(certificado));
  }

  CertificadoCapturado? buscar(String certificadoId) {
    final mapa = _metadata.get(certificadoId);
    return mapa == null ? null : _daMapa(mapa);
  }

  List<CertificadoCapturado> listarTodos() {
    return _metadata.values.map(_daMapa).toList(growable: false);
  }

  Future<void> remover(String certificadoId) async {
    await _metadata.delete(certificadoId);
    await _imagens.delete(certificadoId);
  }

  Map<String, dynamic> _paraMapa(CertificadoCapturado c) => {
        'id': c.id,
        'caminhoImagemLocal': c.caminhoImagemLocal,
        'mimeType': c.mimeType,
        'status': c.status.name,
        'tituloExtraido': c.tituloExtraido,
        'instituicaoExtraida': c.instituicaoExtraida,
        'cargaHorariaExtraidaHoras': c.cargaHorariaExtraidaHoras,
        'dataExtraida': c.dataExtraida?.toIso8601String(),
        'vinculoSugerido': c.vinculoSugerido == null
            ? null
            : {
                'idItemLattesReferenciado': c.vinculoSugerido!.idItemLattesReferenciado,
                'descricaoItemLattes': c.vinculoSugerido!.descricaoItemLattes,
                'confianca': c.vinculoSugerido!.confianca,
              },
        'caminhoPdfConvertido': c.caminhoPdfConvertido,
        'idArquivoCloud': c.idArquivoCloud,
        'mensagemErro': c.mensagemErro,
      };

  CertificadoCapturado _daMapa(dynamic mapaBruto) {
    final mapa = Map<String, dynamic>.from(mapaBruto as Map);
    final vinculoBruto = mapa['vinculoSugerido'];

    return CertificadoCapturado(
      id: mapa['id'] as String,
      caminhoImagemLocal: mapa['caminhoImagemLocal'] as String,
      // Fallback para dados persistidos antes deste campo existir.
      mimeType: mapa['mimeType'] as String? ?? 'image/jpeg',
      status: StatusCertificado.values.byName(mapa['status'] as String),
      tituloExtraido: mapa['tituloExtraido'] as String?,
      instituicaoExtraida: mapa['instituicaoExtraida'] as String?,
      cargaHorariaExtraidaHoras: mapa['cargaHorariaExtraidaHoras'] as int?,
      dataExtraida:
          mapa['dataExtraida'] == null ? null : DateTime.parse(mapa['dataExtraida'] as String),
      vinculoSugerido: vinculoBruto == null
          ? null
          : VinculoSugerido(
              idItemLattesReferenciado:
                  (vinculoBruto as Map)['idItemLattesReferenciado'] as String,
              descricaoItemLattes: vinculoBruto['descricaoItemLattes'] as String,
              confianca: (vinculoBruto['confianca'] as num).toDouble(),
            ),
      caminhoPdfConvertido: mapa['caminhoPdfConvertido'] as String?,
      idArquivoCloud: mapa['idArquivoCloud'] as String?,
      mensagemErro: mapa['mensagemErro'] as String?,
    );
  }
}
