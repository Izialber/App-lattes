import 'package:fpdart/fpdart.dart' show Either;

import '../../../../core/error/failures.dart';
import '../entities/curriculo_lattes.dart';
import '../repositories/lattes_repository.dart';

/// Caso de uso único do módulo 1: recebe o conteúdo textual do XML
/// (independente de como foi obtido — seletor de arquivo no mobile ou
/// drag&drop no desktop, ambos resolvidos antes de chegar aqui pela camada
/// de apresentação) e devolve o currículo estruturado ou uma falha de
/// domínio.
class ImportarCurriculoLattes {
  final LattesRepository _repository;

  const ImportarCurriculoLattes(this._repository);

  Either<Failure, CurriculoLattes> call(String xmlContent) {
    return _repository.parseXmlContent(xmlContent);
  }
}
