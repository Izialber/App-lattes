import 'package:equatable/equatable.dart';

/// Proficiência em idioma (seção `DADOS-GERAIS/IDIOMAS/IDIOMA` do XML do
/// Lattes). Os valores de proficiência vêm como códigos do Lattes (ex.:
/// "BEM", "RAZOAVEL", "POUCO", "NADA") — preservados como veio, sem
/// tradução, para não inventar rótulos que o usuário não escreveu.
class Idioma extends Equatable {
  final String descricao;
  final String? proficienciaLeitura;
  final String? proficienciaFala;
  final String? proficienciaEscrita;
  final String? proficienciaCompreensao;

  const Idioma({
    required this.descricao,
    this.proficienciaLeitura,
    this.proficienciaFala,
    this.proficienciaEscrita,
    this.proficienciaCompreensao,
  });

  @override
  List<Object?> get props => [
        descricao,
        proficienciaLeitura,
        proficienciaFala,
        proficienciaEscrita,
        proficienciaCompreensao,
      ];
}
