/// As seções do currículo Lattes que recebem comprovante de arquivo neste
/// módulo. `areasDeAtuacao` (tags de texto livre) fica de fora — não é um
/// item individual com um comprovante natural, ao contrário das demais
/// seções (ver DECISOES.md).
enum CategoriaEntradaLattes {
  curso,
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
        CategoriaEntradaLattes.curso => 'Formação acadêmica',
        CategoriaEntradaLattes.experienciaProfissional => 'Experiência profissional',
        CategoriaEntradaLattes.publicacao => 'Produção bibliográfica',
        CategoriaEntradaLattes.orientacao => 'Orientações',
        CategoriaEntradaLattes.producaoTecnica => 'Produção técnica',
        CategoriaEntradaLattes.participacaoEvento => 'Participação em eventos',
        CategoriaEntradaLattes.projetoPesquisa => 'Projetos de pesquisa',
        CategoriaEntradaLattes.idioma => 'Idiomas',
      };
}
