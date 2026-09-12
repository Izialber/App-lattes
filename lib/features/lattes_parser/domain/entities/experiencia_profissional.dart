import 'package:equatable/equatable.dart';

/// Vínculo profissional (empregatício ou institucional) listado no Lattes.
///
/// `dataFim` nula significa vínculo em andamento — mas o schema do CNPq não
/// distingue de forma inequívoca "vínculo em andamento" de "usuário não
/// preencheu a data de fim" quando o atributo `ANO-DE-FIM` está ausente
/// (ver DECISOES.md, item "Ambiguidade vínculo em andamento"). Por decisão
/// explícita do usuário, essa ambiguidade NÃO é resolvida silenciosamente:
/// o parser assume `vinculoAtual: true` como leitura mais provável, mas
/// marca `precisaConfirmacaoVinculoAtual: true`, e a tela de importação do
/// Lattes deve perguntar ao usuário ("este vínculo com [instituição] ainda
/// está ativo?") antes de deixar o vínculo entrar no dossiê sem revisão.
/// Quando `ANO-DE-FIM` está presente no XML, não há ambiguidade — a
/// confirmação nunca é necessária nesse caso.
class ExperienciaProfissional extends Equatable {
  final String instituicao;
  final String? cargo;
  final DateTime? dataInicio;
  final DateTime? dataFim;
  final bool vinculoAtual;
  final bool precisaConfirmacaoVinculoAtual;

  const ExperienciaProfissional({
    required this.instituicao,
    this.cargo,
    this.dataInicio,
    this.dataFim,
    this.vinculoAtual = false,
    this.precisaConfirmacaoVinculoAtual = false,
  });

  /// Usado por `ConfirmarVinculoAtual` para gravar a resposta do usuário e
  /// encerrar o estado de pendência de confirmação.
  ///
  /// `limparDataFim: true` zera `dataFim` explicitamente (caso o usuário
  /// confirme que o vínculo ainda está ativo) — um parâmetro nomeado à
  /// parte de `dataFim` porque `null` como valor de `dataFim` normalmente
  /// significaria "não alterar" num `copyWith` convencional, e aqui
  /// precisamos poder alterar PARA null de forma inequívoca.
  ExperienciaProfissional copyWith({
    DateTime? dataFim,
    bool limparDataFim = false,
    bool? vinculoAtual,
    bool? precisaConfirmacaoVinculoAtual,
  }) {
    return ExperienciaProfissional(
      instituicao: instituicao,
      cargo: cargo,
      dataInicio: dataInicio,
      dataFim: limparDataFim ? null : (dataFim ?? this.dataFim),
      vinculoAtual: vinculoAtual ?? this.vinculoAtual,
      precisaConfirmacaoVinculoAtual:
          precisaConfirmacaoVinculoAtual ?? this.precisaConfirmacaoVinculoAtual,
    );
  }

  @override
  List<Object?> get props =>
      [instituicao, cargo, dataInicio, dataFim, vinculoAtual, precisaConfirmacaoVinculoAtual];
}
