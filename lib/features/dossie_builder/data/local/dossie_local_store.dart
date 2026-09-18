import 'dart:typed_data';

import 'package:hive_ce/hive_ce.dart';

import '../../domain/entities/criterio_pontuacao.dart';
import '../../domain/entities/dossie.dart';
import '../../domain/entities/edital.dart';
import '../../domain/entities/vinculo_aprovado.dart';

/// Persistência do módulo 4 em Hive (IndexedDB no web) — mesmo padrão de
/// `CertificateLocalStore`/`UploadQueueLocalStore`: o `Dossie`/`Edital`
/// (pequenos, metadados) e os bytes do PDF final (potencialmente grandes)
/// em boxes separadas. Precisa sobreviver a reload de aba durante a
/// revisão humana do checklist — requisito explícito do módulo 4 (o
/// `Dossie` também precisa sobreviver a TROCA de dispositivo dentro do
/// mesmo fluxo, mas isso é responsabilidade do usuário reimportar, já que
/// não há sincronização de estado entre dispositivos neste app).
class DossieLocalStore {
  const DossieLocalStore();

  static const dossieBoxName = 'dossie_metadata';
  static const editalBoxName = 'edital_metadata';
  static const pdfFinalBoxName = 'dossie_pdf_final';

  Box<Map> get _dossies => Hive.box<Map>(dossieBoxName);
  Box<Map> get _editais => Hive.box<Map>(editalBoxName);
  Box<Uint8List> get _pdfsFinais => Hive.box<Uint8List>(pdfFinalBoxName);

  Future<void> salvarDossie(Dossie dossie) => _dossies.put(dossie.id, _dossieParaMapa(dossie));

  Dossie? buscarDossie(String id) {
    final mapa = _dossies.get(id);
    return mapa == null ? null : _dossieDaMapa(mapa);
  }

  List<Dossie> listarDossies() => _dossies.values.map(_dossieDaMapa).toList(growable: false);

  Future<void> salvarEdital(Edital edital) => _editais.put(edital.id, _editalParaMapa(edital));

  Edital? buscarEdital(String id) {
    final mapa = _editais.get(id);
    return mapa == null ? null : _editalDaMapa(mapa);
  }

  Future<void> salvarPdfFinal(String dossieId, List<int> bytes) {
    return _pdfsFinais.put(dossieId, Uint8List.fromList(bytes));
  }

  Uint8List? lerPdfFinal(String dossieId) => _pdfsFinais.get(dossieId);

  Map<String, dynamic> _dossieParaMapa(Dossie d) => {
        'id': d.id,
        'editalId': d.editalId,
        'status': d.status.name,
        'vinculosRevisados': d.vinculosRevisados
            .map((v) => {
                  'certificadoId': v.certificadoId,
                  'criterioId': v.criterioId,
                  'decisao': v.decisao.name,
                  'observacaoUsuario': v.observacaoUsuario,
                })
            .toList(),
        'caminhoPdfFinal': d.caminhoPdfFinal,
        'mensagemDegradacao': d.mensagemDegradacao,
        'loteAtual': d.loteAtual,
        'totalDeLotes': d.totalDeLotes,
      };

  Dossie _dossieDaMapa(dynamic mapaBruto) {
    final mapa = Map<String, dynamic>.from(mapaBruto as Map);
    final vinculosBrutos = (mapa['vinculosRevisados'] as List?) ?? const [];

    return Dossie(
      id: mapa['id'] as String,
      editalId: mapa['editalId'] as String,
      status: StatusDossie.values.byName(mapa['status'] as String),
      vinculosRevisados: vinculosBrutos.map((vBruto) {
        final v = Map<String, dynamic>.from(vBruto as Map);
        return VinculoAprovado(
          certificadoId: v['certificadoId'] as String,
          criterioId: v['criterioId'] as String,
          decisao: DecisaoVinculo.values.byName(v['decisao'] as String),
          observacaoUsuario: v['observacaoUsuario'] as String?,
        );
      }).toList(),
      caminhoPdfFinal: mapa['caminhoPdfFinal'] as String?,
      mensagemDegradacao: mapa['mensagemDegradacao'] as String?,
      loteAtual: mapa['loteAtual'] as int? ?? 0,
      totalDeLotes: mapa['totalDeLotes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> _editalParaMapa(Edital e) => {
        'id': e.id,
        'nomeArquivoOriginal': e.nomeArquivoOriginal,
        'orgaoOuBanca': e.orgaoOuBanca,
        'criterios': e.criterios
            .map((c) => {
                  'id': c.id,
                  'descricao': c.descricao,
                  'pontosPorUnidade': c.pontosPorUnidade,
                  'limiteMaximoUnidades': c.limiteMaximoUnidades,
                })
            .toList(),
      };

  Edital _editalDaMapa(dynamic mapaBruto) {
    final mapa = Map<String, dynamic>.from(mapaBruto as Map);
    final criteriosBrutos = (mapa['criterios'] as List?) ?? const [];

    return Edital(
      id: mapa['id'] as String,
      nomeArquivoOriginal: mapa['nomeArquivoOriginal'] as String,
      orgaoOuBanca: mapa['orgaoOuBanca'] as String?,
      criterios: criteriosBrutos.map((cBruto) {
        final c = Map<String, dynamic>.from(cBruto as Map);
        return CriterioPontuacao(
          id: c['id'] as String,
          descricao: c['descricao'] as String,
          pontosPorUnidade: (c['pontosPorUnidade'] as num?)?.toDouble(),
          limiteMaximoUnidades: c['limiteMaximoUnidades'] as int?,
        );
      }).toList(),
    );
  }
}
