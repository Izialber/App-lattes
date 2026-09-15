import 'package:equatable/equatable.dart';

enum TipoProducaoTecnica {
  software,
  produtoTecnologico,
  apresentacaoDeTrabalho,
  programaDeRadioOuTv,
  midiaSocialWebsiteBlog,
  outro,
}

/// Item de produção técnica (seção `PRODUCAO-TECNICA`, filha direta da raiz
/// do XML do Lattes — não de `OUTRA-PRODUCAO`, apesar do nome sugerir isso;
/// ver DECISOES.md). Cobre as subseções com dado real observado em
/// currículos de usuários: software, produto tecnológico, apresentação de
/// trabalho, programa de rádio/TV, mídia social/website/blog. Demais
/// subseções do Lattes (processos/técnicas, maquetes etc.) ficam fora do
/// escopo, mesmo padrão de decisão já aplicado à produção bibliográfica.
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
