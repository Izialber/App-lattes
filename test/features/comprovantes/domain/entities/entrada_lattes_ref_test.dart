import 'package:flutter_test/flutter_test.dart';

import 'package:certificados_lattes/features/comprovantes/domain/entities/categoria_entrada_lattes.dart';
import 'package:certificados_lattes/features/comprovantes/domain/entities/entrada_lattes_ref.dart';
import 'package:certificados_lattes/features/comprovantes/domain/entities/mapear_entradas_lattes.dart';
import 'package:certificados_lattes/features/lattes_parser/domain/entities/curriculo_lattes.dart';
import 'package:certificados_lattes/features/lattes_parser/domain/entities/curso.dart';
import 'package:certificados_lattes/features/lattes_parser/domain/entities/experiencia_profissional.dart';

void main() {
  group('gerarIdEntrada', () {
    test('é determinístico: mesmos campos geram o mesmo id', () {
      final id1 = gerarIdEntrada(CategoriaEntradaLattes.curso, ['Mestrado', 'UFX', 2020]);
      final id2 = gerarIdEntrada(CategoriaEntradaLattes.curso, ['Mestrado', 'UFX', 2020]);
      expect(id1, id2);
    });

    test('ignora diferença de maiúsculas/espaços em branco', () {
      final id1 = gerarIdEntrada(CategoriaEntradaLattes.curso, ['Mestrado', 'UFX', 2020]);
      final id2 = gerarIdEntrada(CategoriaEntradaLattes.curso, [' mestrado ', 'ufx', 2020]);
      expect(id1, id2);
    });

    test('categorias diferentes com o mesmo texto-base não colidem', () {
      final idCurso = gerarIdEntrada(CategoriaEntradaLattes.curso, ['Curso X', 2020]);
      final idPublicacao = gerarIdEntrada(CategoriaEntradaLattes.publicacao, ['Curso X', 2020]);
      expect(idCurso, isNot(idPublicacao));
    });

    test('id muda quando um campo identificador muda', () {
      final id1 = gerarIdEntrada(CategoriaEntradaLattes.curso, ['Mestrado', 'UFX', 2020]);
      final id2 = gerarIdEntrada(CategoriaEntradaLattes.curso, ['Mestrado', 'UFX', 2021]);
      expect(id1, isNot(id2));
    });

    test('campos nulos não lançam e ainda produzem um id estável', () {
      final id1 = gerarIdEntrada(CategoriaEntradaLattes.curso, ['Curso Y', null, null]);
      final id2 = gerarIdEntrada(CategoriaEntradaLattes.curso, ['Curso Y', null, null]);
      expect(id1, id2);
    });
  });

  group('gerarEntradasLattes', () {
    test('achata todas as categorias preservando a ordem de cada lista', () {
      final curriculo = CurriculoLattes(
        nomeCompleto: 'Fulano',
        cursos: const [
          Curso(nivel: NivelCurso.graduacao, nomeCurso: 'Curso A'),
          Curso(nivel: NivelCurso.mestrado, nomeCurso: 'Curso B'),
        ],
        experienciasProfissionais: const [
          ExperienciaProfissional(instituicao: 'Empresa X'),
        ],
      );

      final entradas = gerarEntradasLattes(curriculo);

      expect(entradas, hasLength(3));
      expect(entradas[0].titulo, 'Curso A');
      expect(entradas[1].titulo, 'Curso B');
      expect(entradas[2].titulo, 'Empresa X');
      expect(entradas[0].categoria, CategoriaEntradaLattes.curso);
      expect(entradas[2].categoria, CategoriaEntradaLattes.experienciaProfissional);
    });

    test('ids diferentes para duas entradas distintas na mesma categoria', () {
      final curriculo = CurriculoLattes(
        nomeCompleto: 'Fulano',
        cursos: const [
          Curso(nivel: NivelCurso.graduacao, nomeCurso: 'Curso A'),
          Curso(nivel: NivelCurso.graduacao, nomeCurso: 'Curso B'),
        ],
      );

      final entradas = gerarEntradasLattes(curriculo);

      expect(entradas[0].id, isNot(entradas[1].id));
    });

    test('reimportar o mesmo XML gera os mesmos ids (estabilidade)', () {
      CurriculoLattes montarCurriculo() => CurriculoLattes(
            nomeCompleto: 'Fulano',
            cursos: const [Curso(nivel: NivelCurso.graduacao, nomeCurso: 'Curso A')],
          );

      final ids1 = gerarEntradasLattes(montarCurriculo()).map((e) => e.id).toList();
      final ids2 = gerarEntradasLattes(montarCurriculo()).map((e) => e.id).toList();

      expect(ids1, ids2);
    });

    test('separa formação acadêmica de formação complementar (cursoCurta)', () {
      final curriculo = CurriculoLattes(
        nomeCompleto: 'Fulano',
        cursos: const [
          Curso(nivel: NivelCurso.graduacao, nomeCurso: 'Licenciatura'),
          Curso(nivel: NivelCurso.cursoCurta, nomeCurso: 'Workshop de X'),
          Curso(nivel: NivelCurso.graduacao, nomeCurso: 'Engenharia'),
          Curso(nivel: NivelCurso.cursoCurta, nomeCurso: 'Bootcamp de Z'),
        ],
      );

      final entradas = gerarEntradasLattes(curriculo);
      final academicas = entradas.where((e) => e.categoria == CategoriaEntradaLattes.curso).toList();
      final complementares =
          entradas.where((e) => e.categoria == CategoriaEntradaLattes.formacaoComplementar).toList();

      expect(academicas.map((e) => e.titulo), ['Licenciatura', 'Engenharia']);
      expect(complementares.map((e) => e.titulo), ['Workshop de X', 'Bootcamp de Z']);
    });

    test('discrimina técnico, graduação, pós lato sensu e pós stricto sensu', () {
      final curriculo = CurriculoLattes(
        nomeCompleto: 'Fulano',
        cursos: const [
          Curso(nivel: NivelCurso.tecnico, nomeCurso: 'Técnico em Informática'),
          Curso(nivel: NivelCurso.graduacao, nomeCurso: 'Licenciatura'),
          Curso(nivel: NivelCurso.especializacao, nomeCurso: 'MBA em Gestão'),
          Curso(nivel: NivelCurso.mestrado, nomeCurso: 'Mestrado em Y'),
          Curso(nivel: NivelCurso.doutorado, nomeCurso: 'Doutorado em Z'),
        ],
      );

      final entradas = gerarEntradasLattes(curriculo);
      CategoriaEntradaLattes categoriaDe(String titulo) =>
          entradas.firstWhere((e) => e.titulo == titulo).categoria;

      expect(categoriaDe('Técnico em Informática'), CategoriaEntradaLattes.tecnico);
      expect(categoriaDe('Licenciatura'), CategoriaEntradaLattes.curso);
      expect(categoriaDe('MBA em Gestão'), CategoriaEntradaLattes.posLatoSensu);
      expect(categoriaDe('Mestrado em Y'), CategoriaEntradaLattes.posStrictoSensu);
      expect(categoriaDe('Doutorado em Z'), CategoriaEntradaLattes.posStrictoSensu);
    });
  });
}
