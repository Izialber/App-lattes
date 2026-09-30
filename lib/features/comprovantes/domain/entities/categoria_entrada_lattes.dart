/// As seções do currículo Lattes que recebem comprovante de arquivo neste
/// módulo. `areasDeAtuacao` (tags de texto livre) fica de fora — não é um
/// item individual com um comprovante natural, ao contrário das demais
/// seções (ver DECISOES.md).
enum CategoriaEntradaLattes {
  tecnico,
  curso, // graduação — nome do valor mantido por compatibilidade de id
  // (ver gerarIdEntrada), só especialização/mestrado/doutorado/pós-doutorado
  // saíram daqui pras duas categorias novas abaixo (ver DECISOES.md).
  posLatoSensu,
  posStrictoSensu,
  formacaoComplementar,
  experienciaProfissional,
  publicacao,
  orientacao,
  producaoTecnica,
  participacaoEvento,
  projetoPesquisa,
  idioma,
}

/// Rótulo em português pra exibição — usado tanto pela tela de comprovantes
/// (título de cada seção) quanto pelo módulo de sincronização com o Drive
/// (nome da subpasta por categoria, ver `ComprovantesSyncController`).
extension CategoriaEntradaLattesRotulo on CategoriaEntradaLattes {
  String get rotulo => switch (this) {
        CategoriaEntradaLattes.tecnico => 'Técnico',
        CategoriaEntradaLattes.curso => 'Graduação',
        CategoriaEntradaLattes.posLatoSensu => 'Pós-graduação lato sensu',
        CategoriaEntradaLattes.posStrictoSensu => 'Pós-graduação stricto sensu',
        CategoriaEntradaLattes.formacaoComplementar => 'Formação complementar',
        CategoriaEntradaLattes.experienciaProfissional => 'Experiência profissional',
        CategoriaEntradaLattes.publicacao => 'Produção bibliográfica',
        CategoriaEntradaLattes.orientacao => 'Orientações',
        CategoriaEntradaLattes.producaoTecnica => 'Produção técnica',
        CategoriaEntradaLattes.participacaoEvento => 'Participação em eventos',
        CategoriaEntradaLattes.projetoPesquisa => 'Projetos de pesquisa',
        CategoriaEntradaLattes.idioma => 'Idiomas',
      };
}
