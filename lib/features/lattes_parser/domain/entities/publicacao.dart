import 'package:equatable/equatable.dart';

enum TipoPublicacao {
  artigoPeriodico,
  trabalhoEvento,
  capituloLivro,
  livroPublicado,
  outro,
}

/// Uma publicação bibliográfica do currículo. `doi` e `paginas` são
/// frequentemente ausentes no XML real (campo opcional não preenchido pelo
/// usuário no Lattes) — por isso são nulos em vez de string vazia, o que
/// permite à UI diferenciar "não informado" de "informado como vazio".
class Publicacao extends Equatable {
  final TipoPublicacao tipo;
  final String titulo;
  final int? ano;
  final String? doi;
  final String? nomeVeiculo; // periódico, evento, editora etc.
  final List<String> autores;

  const Publicacao({
    required this.tipo,
    required this.titulo,
    this.ano,
    this.doi,
    this.nomeVeiculo,
    this.autores = const [],
  });

  @override
  List<Object?> get props => [tipo, titulo, ano, doi, nomeVeiculo, autores];
}
