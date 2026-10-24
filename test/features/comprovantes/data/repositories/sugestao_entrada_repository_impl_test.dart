import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;
import 'package:mocktail/mocktail.dart';

import 'package:certificados_lattes/core/error/failures.dart';
import 'package:certificados_lattes/features/comprovantes/data/repositories/sugestao_entrada_repository_impl.dart';
import 'package:certificados_lattes/features/comprovantes/domain/entities/categoria_entrada_lattes.dart';
import 'package:certificados_lattes/features/comprovantes/domain/entities/entrada_lattes_ref.dart';
import 'package:certificados_lattes/features/comprovantes/domain/entities/sugestao_lote.dart';
import 'package:certificados_lattes/features/llm_shared/domain/repositories/llm_repository.dart';

class _MockLlmRepository extends Mock implements LlmRepository {}

const _entradas = [
  EntradaLattesRef(
    id: 'hash-engenharia',
    categoria: CategoriaEntradaLattes.curso,
    titulo: 'Engenharia Elétrica',
    subtitulo: 'Estácio · 2010–2015',
  ),
  EntradaLattesRef(
    id: 'hash-fenep',
    categoria: CategoriaEntradaLattes.participacaoEvento,
    titulo: '7º Congresso FENEP',
    subtitulo: '',
  ),
];

const _arquivos = [
  ArquivoParaSugestao(id: 'uuid-1', caminho: 'Diplomas/Engenharia Elétrica.pdf'),
  ArquivoParaSugestao(id: 'uuid-2', caminho: 'Eventos/fenep.pdf'),
  ArquivoParaSugestao(id: 'uuid-3', caminho: 'CEO Award.pdf'),
];

void main() {
  group('montarTextoMapeamento', () {
    test('usa ids curtos e lista seção, título e detalhes de cada entrada', () {
      final montado = montarTextoMapeamento(_arquivos, _entradas);

      expect(montado.texto, contains('e1 | Graduação | Engenharia Elétrica | Estácio · 2010–2015'));
      // Subtítulo vazio não gera um " | " sobrando no fim.
      expect(montado.texto, contains('e2 | Participação em eventos | 7º Congresso FENEP\n'));
      expect(montado.texto, contains('a1 | Diplomas/Engenharia Elétrica.pdf'));
      expect(montado.texto, isNot(contains('hash-engenharia')));
      expect(montado.texto, isNot(contains('uuid-1')));
      expect(montado.entradaPorIdCurto, {'e1': 'hash-engenharia', 'e2': 'hash-fenep'});
      expect(montado.arquivoPorIdCurto, {'a1': 'uuid-1', 'a2': 'uuid-2', 'a3': 'uuid-3'});
    });
  });

  group('interpretarRespostaMapeamento', () {
    final montado = montarTextoMapeamento(_arquivos, _entradas);

    Map<String, String?> interpretar(Map<String, dynamic> resposta) =>
        interpretarRespostaMapeamento(
          resposta,
          entradaPorIdCurto: montado.entradaPorIdCurto,
          arquivoPorIdCurto: montado.arquivoPorIdCurto,
        );

    test('traduz ids curtos de volta pros ids reais', () {
      expect(
        interpretar({
          'atribuicoes': {'a1': 'e1', 'a2': 'e2', 'a3': null},
        }),
        {'uuid-1': 'hash-engenharia', 'uuid-2': 'hash-fenep', 'uuid-3': null},
      );
    });

    test('id de entrada inventado, valor não-string e arquivo faltando viram null', () {
      expect(
        interpretar({
          'atribuicoes': {'a1': 'e99', 'a2': 2},
        }),
        {'uuid-1': null, 'uuid-2': null, 'uuid-3': null},
      );
    });

    test('tolera espaço e maiúscula nos ids', () {
      expect(
        interpretar({
          'atribuicoes': {' A1 ': ' E1 '},
        })['uuid-1'],
        'hash-engenharia',
      );
    });

    test('chave de arquivo desconhecida é ignorada', () {
      final resultado = interpretar({
        'atribuicoes': {'a1': 'e1', 'a42': 'e2'},
      });
      expect(resultado.keys, ['uuid-1', 'uuid-2', 'uuid-3']);
    });

    test('sem o objeto "atribuicoes" é erro de formato', () {
      expect(() => interpretar({'resultado': []}), throwsFormatException);
    });
  });

  group('SugestaoEntradaRepositoryImpl', () {
    late _MockLlmRepository llm;

    setUp(() => llm = _MockLlmRepository());

    test('sucesso: devolve o mapa já com ids reais', () async {
      when(() => llm.extrairJsonDeTexto(
            texto: any(named: 'texto'),
            promptExtracao: any(named: 'promptExtracao'),
          )).thenAnswer((_) async => const Right({
            'atribuicoes': {'a1': 'e1', 'a2': null, 'a3': null},
          }));

      final resultado = await SugestaoEntradaRepositoryImpl(llm)
          .sugerirPorLlm(arquivos: _arquivos, entradas: _entradas);

      expect(
        resultado.getOrElse((_) => {}),
        {'uuid-1': 'hash-engenharia', 'uuid-2': null, 'uuid-3': null},
      );
    });

    test('falha do provedor passa adiante sem mudar', () async {
      const falha = LlmFailure('Nenhum provedor configurado', isQuotaOrAuth: true);
      when(() => llm.extrairJsonDeTexto(
            texto: any(named: 'texto'),
            promptExtracao: any(named: 'promptExtracao'),
          )).thenAnswer((_) async => const Left(falha));

      final resultado = await SugestaoEntradaRepositoryImpl(llm)
          .sugerirPorLlm(arquivos: _arquivos, entradas: _entradas);

      expect(resultado, const Left(falha));
    });

    test('resposta fora do formato vira LlmFailure (o use case cai no fallback)', () async {
      when(() => llm.extrairJsonDeTexto(
            texto: any(named: 'texto'),
            promptExtracao: any(named: 'promptExtracao'),
          )).thenAnswer((_) async => const Right({'ok': true}));

      final resultado = await SugestaoEntradaRepositoryImpl(llm)
          .sugerirPorLlm(arquivos: _arquivos, entradas: _entradas);

      expect(resultado.isLeft(), isTrue);
      resultado.mapLeft((f) => expect(f, isA<LlmFailure>()));
    });
  });
}
