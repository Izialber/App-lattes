import 'package:fpdart/fpdart.dart' show Either, Unit;

import '../../../../core/error/failures.dart';
import '../entities/codigo_acesso.dart';

/// Sem use cases separados aqui (diferente de outros módulos do projeto,
/// ver DECISOES.md) — cada método já é uma operação atômica sem lógica de
/// negócio adicional fora do repositório; um wrapper de use case seria só
/// um passthrough de uma linha.
abstract class CodigoAcessoRepository {
  /// Resgata um código de uso único: se existir e ainda não tiver sido
  /// usado, marca como usado atomicamente e retorna sucesso. [identificador]
  /// é o e-mail de quem está resgatando (Google ou e-mail/senha), guardado
  /// junto pra auditoria.
  Future<Either<Failure, Unit>> resgatarCodigo({
    required String codigo,
    required String identificador,
  });

  /// Se este e-mail já resgatou um código com sucesso antes — só usado pelo
  /// fluxo Google (ver DECISOES.md); o fluxo e-mail/senha não precisa, já
  /// que o próprio Firebase Auth é o registro de que a conta existe.
  Future<Either<Failure, bool>> emailAutorizado(String email);

  /// Admin: lista todos os códigos (uso único visível, quem usou, quando).
  Future<Either<Failure, List<CodigoAcesso>>> listarCodigos();

  /// Admin: gera e persiste um novo código de uso único.
  Future<Either<Failure, CodigoAcesso>> criarCodigo({String? rotulo});

  /// Admin: remove um código ainda não usado.
  Future<Either<Failure, Unit>> revogarCodigo(String codigo);
}
