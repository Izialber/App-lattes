import 'package:equatable/equatable.dart';

enum NivelCurso {
  graduacao,
  especializacao,
  mestrado,
  doutorado,
  posDoutorado,
  cursoCurta, // curso de extensão/capacitação curta duração
  outro,
}

/// Formação acadêmica ou curso de curta duração listado no Lattes.
/// `cargaHorariaHoras` é comumente ausente para graduação/pós (o Lattes não
/// exige esse campo para todos os níveis), por isso é nulo, não zero — zero
/// horas seria uma afirmação factual incorreta.
class Curso extends Equatable {
  final NivelCurso nivel;
  final String nomeCurso;
  final String? instituicao;
  final int? anoInicio;
  final int? anoConclusao;
  final int? cargaHorariaHoras;
  final String? situacao; // "Concluído", "Em andamento" etc., texto livre do XML

  const Curso({
    required this.nivel,
    required this.nomeCurso,
    this.instituicao,
    this.anoInicio,
    this.anoConclusao,
    this.cargaHorariaHoras,
    this.situacao,
  });

  @override
  List<Object?> get props =>
      [nivel, nomeCurso, instituicao, anoInicio, anoConclusao, cargaHorariaHoras, situacao];
}
