import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Left, Right;
import 'package:mocktail/mocktail.dart';

import 'package:certificados_lattes/core/error/failures.dart';
import 'package:certificados_lattes/features/certificate_capture/data/datasources/llm_extraction_datasource.dart';
import 'package:certificados_lattes/features/llm_shared/domain/repositories/llm_repository.dart';

class MockLlmRepository extends Mock implements LlmRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLlmRepository llmRepository;
  late LlmExtractionDatasource datasource;

  setUp(() {
    llmRepository = MockLlmRepository();
    datasource = LlmExtractionDatasource(llmRepository);
  });

  test('retorna o JSON quando titulo e instituicao estão presentes', () async {
    when(() => llmRepository.extrairJsonDeImagem(
          imagemBytes: any(named: 'imagemBytes'),
          mimeType: any(named: 'mimeType'),
          promptExtracao: any(named: 'promptExtracao'),
        )).thenAnswer((_) async => const Right({'titulo': 'Curso X', 'instituicao': 'UFX'}));

    final resultado =
        await datasource.extrair(imagemBytes: const [1, 2, 3], mimeType: 'image/jpeg');

    expect(resultado.isRight(), isTrue);
  });

  test('LlmFailure quando "titulo" está faltando na resposta do modelo', () async {
    when(() => llmRepository.extrairJsonDeImagem(
          imagemBytes: any(named: 'imagemBytes'),
          mimeType: any(named: 'mimeType'),
          promptExtracao: any(named: 'promptExtracao'),
        )).thenAnswer((_) async => const Right({'instituicao': 'UFX'}));

    final resultado =
        await datasource.extrair(imagemBytes: const [1, 2, 3], mimeType: 'image/jpeg');

    expect(resultado.isLeft(), isTrue);
    resultado.match((falha) => expect(falha, isA<LlmFailure>()), (_) => fail('esperava Left'));
  });

  test('propaga a falha do repositório sem alteração', () async {
    when(() => llmRepository.extrairJsonDeImagem(
          imagemBytes: any(named: 'imagemBytes'),
          mimeType: any(named: 'mimeType'),
          promptExtracao: any(named: 'promptExtracao'),
        )).thenAnswer((_) async => const Left(LlmFailure('chave inválida')));

    final resultado =
        await datasource.extrair(imagemBytes: const [1, 2, 3], mimeType: 'image/jpeg');

    expect(resultado.isLeft(), isTrue);
  });

  test('carrega o prompt real do asset e o envia ao repositório', () async {
    String? promptCapturado;
    when(() => llmRepository.extrairJsonDeImagem(
          imagemBytes: any(named: 'imagemBytes'),
          mimeType: any(named: 'mimeType'),
          promptExtracao: any(named: 'promptExtracao'),
        )).thenAnswer((invocation) async {
      promptCapturado = invocation.namedArguments[#promptExtracao] as String;
      return const Right({'titulo': 't', 'instituicao': 'i'});
    });

    await datasource.extrair(imagemBytes: const [1, 2, 3], mimeType: 'image/jpeg');

    expect(promptCapturado, isNotNull);
    expect(promptCapturado, contains('titulo'));
    expect(promptCapturado, contains('instituicao'));
  });
}
