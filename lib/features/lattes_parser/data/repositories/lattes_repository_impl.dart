import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../../domain/entities/curriculo_lattes.dart';
import '../../domain/repositories/lattes_repository.dart';
import '../parsers/lattes_xml_parser.dart';

/// Implementação do repositório do módulo 1. Única responsabilidade além de
/// delegar ao parser: garantir que NENHUMA exceção cruze a fronteira para o
/// domínio — tudo vira [LattesParseFailure] (requisito do projeto: "nunca
/// lançar exceção não tratada por campo faltante").
class LattesRepositoryImpl implements LattesRepository {
  final LattesXmlParser _parser;

  const LattesRepositoryImpl([this._parser = const LattesXmlParser()]);

  @override
  Either<Failure, CurriculoLattes> parseXmlContent(String xmlContent) {
    if (xmlContent.trim().isEmpty) {
      return Either.left(const LattesParseFailure('O arquivo selecionado está vazio.'));
    }

    try {
      final curriculo = _parser.parse(xmlContent);
      return Either.right(curriculo);
    } on LattesXmlParseException catch (e) {
      return Either.left(LattesParseFailure(e.message));
    } catch (e) {
      // Rede de segurança final: mesmo um erro totalmente inesperado (ex.:
      // stack overflow em XML profundamente aninhado, bug não previsto)
      // vira uma Failure de domínio, nunca uma exceção não tratada.
      return Either.left(LattesParseFailure('Erro inesperado ao ler o currículo: $e'));
    }
  }
}
