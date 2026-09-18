import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../../../certificate_capture/domain/entities/certificado_capturado.dart';
import '../entities/dossie.dart';
import '../entities/edital.dart';
import '../entities/vinculo_aprovado.dart';
import '../entities/vinculo_sugerido_dossie.dart';

abstract class DossieRepository {
  /// Extrai os critérios de pontuação do PDF do edital via LLM. Resultado é
  /// sempre sugestão (ver docstring de [Edital]). [nomeArquivoOriginal] vem
  /// de quem chama (a UI sabe o nome do arquivo escolhido pelo usuário) —
  /// nem o LLM nem o PDF em si têm como fornecer isso de forma confiável.
  Future<Either<Failure, Edital>> extrairCriterios({
    required String editalId,
    required String nomeArquivoOriginal,
    required List<int> editalPdfBytes,
  });

  /// Cruza os critérios do edital com os certificados já sincronizados e
  /// gera sugestões de vínculo (nunca aprovadas automaticamente — cada uma
  /// exige uma [VinculoAprovado] explícita do usuário antes de valer para a
  /// compilação final).
  Future<Either<Failure, List<VinculoSugeridoDossie>>> sugerirVinculos({
    required Edital edital,
    required List<CertificadoCapturado> certificadosSincronizados,
  });

  /// Persiste a decisão humana (aprovar/alterar/excluir) sobre um vínculo.
  /// Chamado a cada interação no checklist, não só ao final, para que o
  /// progresso da revisão sobreviva a reload de aba.
  Future<Either<Failure, Dossie>> registrarDecisaoVinculo({
    required String dossieId,
    required VinculoAprovado decisao,
  });

  /// Compila o dossiê final, escolhendo entre mesclagem direta, mesclagem em
  /// partes (lotes sequenciais, com `Dossie.loteAtual`/`totalDeLotes`
  /// atualizados a cada lote), ou degradação explícita — decisão feita por
  /// `DecidirEstrategiaDeMemoria` ANTES de qualquer bytes de PDF ser
  /// processado. Só retorna `Either.left(InsufficientDeviceMemoryFailure)`
  /// no caso `EstrategiaMesclagemDossie.inviavelNoDispositivo` (nem o maior
  /// certificado isolado cabe no dispositivo atual) — a UI então troca o
  /// status do dossiê para `StatusDossie.degradadoAguardandoDesktop`. Nos
  /// outros dois casos, a compilação prossegue sem intervenção do usuário.
  Future<Either<Failure, Dossie>> compilarDossieFinal(String dossieId);
}
