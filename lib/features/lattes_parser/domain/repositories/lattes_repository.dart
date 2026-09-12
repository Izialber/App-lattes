import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../entities/curriculo_lattes.dart';

/// Contrato do repositório de currículo Lattes. A implementação (`data/`)
/// decide COMO o XML chega (file_picker, drag&drop) e COMO é parseado;
/// o domínio só conhece "dado um conteúdo de arquivo, devolva um currículo
/// ou uma falha".
///
/// Nota de dependência: `Either` vem de `fpdart`, não listado no pubspec
/// principal por não ser estritamente necessário (poderíamos modelar com
/// exceptions tipadas); ver DECISOES.md, item "Either vs exceptions" para a
/// decisão tomada e como reverter caso `fpdart` não seja aprovado.
abstract class LattesRepository {
  /// Faz o parsing de um conteúdo XML bruto (já lido do arquivo escolhido
  /// pelo usuário) e retorna o currículo estruturado.
  Either<Failure, CurriculoLattes> parseXmlContent(String xmlContent);
}
