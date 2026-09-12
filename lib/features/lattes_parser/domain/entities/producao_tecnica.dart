import 'package:equatable/equatable.dart';

enum TipoProducaoTecnica { software, produtoTecnologico, outro }

/// Item de produção técnica (seção `PRODUCAO-TECNICA` dentro de
/// `OUTRA-PRODUCAO` no XML do Lattes) — adicionada junto com [Orientacao]
/// na expansão de escopo decidida pelo usuário. Cobre apenas software e
/// produto tecnológico nesta versão (as duas categorias mais comumente
/// exigidas em critérios de Prova de Títulos de concursos técnicos); as
/// demais subseções de produção técnica do Lattes (processos/técnicas,
/// maquetes, mídia social etc.) ficam fora do escopo, mesmo padrão de
/// decisão já aplicado à produção bibliográfica (ver DECISOES.md).
class ProducaoTecnica extends Equatable {
  final TipoProducaoTecnica tipo;
  final String titulo;
  final int? ano;
  final String? finalidadeOuNatureza;

  const ProducaoTecnica({
    required this.tipo,
    required this.titulo,
    this.ano,
    this.finalidadeOuNatureza,
  });

  @override
  List<Object?> get props => [tipo, titulo, ano, finalidadeOuNatureza];
}
