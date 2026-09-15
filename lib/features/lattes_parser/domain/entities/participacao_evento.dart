import 'package:equatable/equatable.dart';

enum TipoParticipacaoEvento { congresso, oficina, exposicao, outra }

/// Participação em evento/congresso (seção `DADOS-COMPLEMENTARES/
/// PARTICIPACAO-EM-EVENTOS-CONGRESSOS` do XML do Lattes) — cobre tanto
/// apresentação de trabalho em evento quanto participação simples (ouvinte,
/// organizador etc.), que no Lattes frequentemente vem sem [titulo] próprio
/// (o formulário do Lattes deixa `TITULO` vazio nesse caso) — por isso o
/// parser cai para o nome do evento como título de exibição.
class ParticipacaoEvento extends Equatable {
  final TipoParticipacaoEvento tipo;
  final String titulo;
  final String? nomeEvento;
  final int? ano;

  const ParticipacaoEvento({
    required this.tipo,
    required this.titulo,
    this.nomeEvento,
    this.ano,
  });

  @override
  List<Object?> get props => [tipo, titulo, nomeEvento, ano];
}
