import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;
import 'package:mocktail/mocktail.dart';

import 'package:certificados_lattes/core/error/failures.dart';
import 'package:certificados_lattes/features/comprovantes/domain/entities/categoria_entrada_lattes.dart';
import 'package:certificados_lattes/features/comprovantes/domain/entities/entrada_lattes_ref.dart';
import 'package:certificados_lattes/features/comprovantes/domain/entities/sugestao_lote.dart';
import 'package:certificados_lattes/features/comprovantes/domain/repositories/sugestao_entrada_repository.dart';
import 'package:certificados_lattes/features/comprovantes/domain/usecases/sugerir_entradas_em_lote.dart';

class _MockRepository extends Mock implements SugestaoEntradaRepository {}

const _engenharia = EntradaLattesRef(
  id: 'eng',
  categoria: CategoriaEntradaLattes.curso,
  titulo: 'Engenharia Elétrica',
  subtitulo: '',
);
const _entradas = [_engenharia];

List<ArquivoParaSugestao> _arquivos(int n) => [
      for (var i = 0; i < n; i++)
        ArquivoParaSugestao(id: 'f$i', caminho: 'Engenharia Elétrica $i.pdf'),
    ];

void main() {
  late _MockRepository repository;

  setUp(() {
    repository = _MockRepository();
  });

  test('LLM respondeu: usa a resposta dele, inclusive os nulls, sem aviso', () async {
    when(() => repository.sugerirPorLlm(
          arquivos: any(named: 'arquivos'),
          entradas: any(named: 'entradas'),
        )).thenAnswer((_) async => const Right({'f0': 'eng', 'f1': null}));

    final resultado = await SugerirEntradasEmLote(repository)(
      arquivos: _arquivos(2),
      entradas: _entradas,
    );

    expect(resultado.avisoFallback, isNull);
    expect(resultado.sugestoes, const [
      SugestaoArquivo(arquivoId: 'f0', entradaId: 'eng', origem: OrigemSugestao.llm),
      // null do LLM é decisão dele ("sem entrada") — a heurística não
      // sobrescreve, mesmo que o nome bata.
      SugestaoArquivo(arquivoId: 'f1', entradaId: null, origem: OrigemSugestao.llm),
    ]);
  });

  test('LLM falhou (ex.: limite da Groq): cai na heurística por nome, com aviso', () async {
    when(() => repository.sugerirPorLlm(
          arquivos: any(named: 'arquivos'),
          entradas: any(named: 'entradas'),
        )).thenAnswer((_) async => const Left(LlmFailure('limite de tokens por minuto')));

    final resultado = await SugerirEntradasEmLote(repository)(
      arquivos: const [
        ArquivoParaSugestao(id: 'a', caminho: 'Diplomas/Engenharia Elétrica.pdf'),
        ArquivoParaSugestao(id: 'b', caminho: 'CEO Award.pdf'),
      ],
      entradas: _entradas,
    );

    expect(resultado.avisoFallback, contains('limite de tokens por minuto'));
    expect(resultado.sugestoes, const [
      SugestaoArquivo(arquivoId: 'a', entradaId: 'eng', origem: OrigemSugestao.nomeDoArquivo),
      SugestaoArquivo(arquivoId: 'b', entradaId: null, origem: OrigemSugestao.nomeDoArquivo),
    ]);
  });

  test('divide em lotes e mantém a ordem dos arquivos', () async {
    when(() => repository.sugerirPorLlm(
          arquivos: any(named: 'arquivos'),
          entradas: any(named: 'entradas'),
        )).thenAnswer((inv) async {
      final lote = inv.namedArguments[#arquivos] as List<ArquivoParaSugestao>;
      return Right({for (final a in lote) a.id: 'eng'});
    });

    final resultado = await SugerirEntradasEmLote(repository, tamanhoLote: 2)(
      arquivos: _arquivos(5),
      entradas: _entradas,
    );

    verify(() => repository.sugerirPorLlm(
          arquivos: any(named: 'arquivos'),
          entradas: any(named: 'entradas'),
        )).called(3);
    expect(resultado.sugestoes.map((s) => s.arquivoId), ['f0', 'f1', 'f2', 'f3', 'f4']);
    expect(resultado.sugestoes.every((s) => s.origem == OrigemSugestao.llm), isTrue);
  });

  test('falha no meio: lotes anteriores ficam com o LLM, os seguintes nem chamam o provedor',
      () async {
    var chamadas = 0;
    when(() => repository.sugerirPorLlm(
          arquivos: any(named: 'arquivos'),
          entradas: any(named: 'entradas'),
        )).thenAnswer((inv) async {
      chamadas++;
      if (chamadas == 2) return const Left(LlmFailure('429'));
      final lote = inv.namedArguments[#arquivos] as List<ArquivoParaSugestao>;
      return Right({for (final a in lote) a.id: 'eng'});
    });

    final resultado = await SugerirEntradasEmLote(repository, tamanhoLote: 2)(
      arquivos: _arquivos(6),
      entradas: _entradas,
    );

    expect(chamadas, 2);
    expect(resultado.sugestoes.map((s) => s.origem), [
      OrigemSugestao.llm,
      OrigemSugestao.llm,
      OrigemSugestao.nomeDoArquivo,
      OrigemSugestao.nomeDoArquivo,
      OrigemSugestao.nomeDoArquivo,
      OrigemSugestao.nomeDoArquivo,
    ]);
    expect(resultado.avisoFallback, contains('primeiros 2 arquivos'));
  });

  test('currículo sem entradas: tudo sem entrada, sem chamar o LLM', () async {
    final resultado = await SugerirEntradasEmLote(repository)(
      arquivos: _arquivos(2),
      entradas: const [],
    );

    verifyNever(() => repository.sugerirPorLlm(
          arquivos: any(named: 'arquivos'),
          entradas: any(named: 'entradas'),
        ));
    expect(resultado.sugestoes.every((s) => s.entradaId == null), isTrue);
  });

  test('arquivo com nome já anexado vai para a entrada dele sem passar pelo LLM', () async {
    when(() => repository.sugerirPorLlm(
          arquivos: any(named: 'arquivos'),
          entradas: any(named: 'entradas'),
        )).thenAnswer((_) async => const Right({'b': null}));

    final resultado = await SugerirEntradasEmLote(repository)(
      arquivos: const [
        ArquivoParaSugestao(id: 'a', caminho: 'Diplomas/diploma-eng.pdf'),
        ArquivoParaSugestao(id: 'b', caminho: 'CEO Award.pdf'),
      ],
      entradas: _entradas,
      entradaJaAnexadaPorNome: const {'diploma-eng.pdf': 'eng'},
    );

    expect(resultado.sugestoes, const [
      SugestaoArquivo(arquivoId: 'a', entradaId: 'eng', origem: OrigemSugestao.jaAnexado),
      SugestaoArquivo(arquivoId: 'b', entradaId: null, origem: OrigemSugestao.llm),
    ]);
    final enviados = verify(() => repository.sugerirPorLlm(
          arquivos: captureAny(named: 'arquivos'),
          entradas: any(named: 'entradas'),
        )).captured.single as List<ArquivoParaSugestao>;
    expect(enviados.map((a) => a.id), ['b']);
  });

  test('vale também quando o LLM falha: o já anexado não cai em "sem entrada"', () async {
    when(() => repository.sugerirPorLlm(
          arquivos: any(named: 'arquivos'),
          entradas: any(named: 'entradas'),
        )).thenAnswer((_) async => const Left(LlmFailure('API key not valid')));

    final resultado = await SugerirEntradasEmLote(repository)(
      arquivos: const [
        ArquivoParaSugestao(id: 'a', caminho: 'IFRJ Semac 5.pdf'),
        ArquivoParaSugestao(id: 'b', caminho: 'CEO Award.pdf'),
      ],
      entradas: _entradas,
      entradaJaAnexadaPorNome: const {'IFRJ Semac 5.pdf': 'eng'},
    );

    expect(resultado.avisoFallback, contains('API key not valid'));
    expect(resultado.sugestoes, const [
      SugestaoArquivo(arquivoId: 'a', entradaId: 'eng', origem: OrigemSugestao.jaAnexado),
      SugestaoArquivo(arquivoId: 'b', entradaId: null, origem: OrigemSugestao.nomeDoArquivo),
    ]);
  });

  test('todos já anexados: nem chama o LLM', () async {
    final resultado = await SugerirEntradasEmLote(repository)(
      arquivos: const [ArquivoParaSugestao(id: 'a', caminho: 'x/diploma-eng.pdf')],
      entradas: _entradas,
      entradaJaAnexadaPorNome: const {'diploma-eng.pdf': 'eng'},
    );

    expect(resultado.avisoFallback, isNull);
    expect(resultado.sugestoes.single.origem, OrigemSugestao.jaAnexado);
    verifyNever(() => repository.sugerirPorLlm(
          arquivos: any(named: 'arquivos'),
          entradas: any(named: 'entradas'),
        ));
  });
}
