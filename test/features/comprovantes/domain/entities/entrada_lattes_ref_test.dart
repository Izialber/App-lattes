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
  });
}
