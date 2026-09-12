import '../entities/experiencia_profissional.dart';

/// Resolve, com resposta explícita do usuário, a ambiguidade descrita em
/// [ExperienciaProfissional.precisaConfirmacaoVinculoAtual]: o XML do Lattes
/// não distingue "vínculo em andamento" de "data de fim não preenchida"
/// quando `ANO-DE-FIM` está ausente. Por decisão do usuário (ver
/// DECISOES.md), essa pergunta é feita explicitamente na tela de importação
/// para cada vínculo ambíguo, em vez de o app assumir silenciosamente.
///
/// Não tem estado próprio nem efeito colateral — apenas transforma a
/// entidade de acordo com a resposta, deixando a camada de apresentação
/// decidir onde/quando persistir a lista atualizada.
class ConfirmarVinculoAtual {
  const ConfirmarVinculoAtual();

  ExperienciaProfissional call(ExperienciaProfissional experiencia, {required bool aindaAtivo}) {
    if (aindaAtivo) {
      return experiencia.copyWith(
        vinculoAtual: true,
        limparDataFim: true,
        precisaConfirmacaoVinculoAtual: false,
      );
    }
    // Usuário confirmou que NÃO está mais ativo, mas o XML não trouxe uma
    // data de fim real (é exatamente essa a ambiguidade). Marcamos
    // vinculoAtual como false; dataFim permanece null porque não temos uma
    // data real para atribuir — a UI deve, idealmente, oferecer um campo
    // para o usuário informar o ano de término manualmente nesse caso
    // (fora do escopo deste use case, que só resolve o campo booleano).
    return experiencia.copyWith(
      vinculoAtual: false,
      precisaConfirmacaoVinculoAtual: false,
    );
  }
}
