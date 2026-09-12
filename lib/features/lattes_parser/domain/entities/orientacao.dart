import 'package:equatable/equatable.dart';

enum NivelOrientacao {
  iniciacaoCientifica,
  especializacao,
  mestrado,
  doutorado,
  posDoutorado,
  outraNatureza,
}

enum SituacaoOrientacao { emAndamento, concluida }

/// Orientação de trabalho acadêmico (dissertação, tese, iniciação
/// científica etc.), seção `OUTRA-PRODUCAO` do XML do Lattes — adicionada
/// por decisão explícita do usuário de expandir a cobertura do parser além
/// de formação/atuação/produção bibliográfica (ver DECISOES.md).
/// `nomeOrientado` é frequentemente omitido em currículos antigos
/// exportados antes de uma mudança de schema do CNPq — por isso é nulo, não
/// obrigatório.
class Orientacao extends Equatable {
  final NivelOrientacao nivel;
  final SituacaoOrientacao situacao;
  final String tituloTrabalho;
  final String? nomeOrientado;
  final int? ano;
  final String? instituicao;

  const Orientacao({
    required this.nivel,
    required this.situacao,
    required this.tituloTrabalho,
    this.nomeOrientado,
    this.ano,
    this.instituicao,
  });

  @override
  List<Object?> get props => [nivel, situacao, tituloTrabalho, nomeOrientado, ano, instituicao];
}
