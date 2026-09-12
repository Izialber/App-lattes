import 'package:fpdart/fpdart.dart' show Either, Unit;

import '../../../../core/error/failures.dart';
import '../entities/cloud_provider.dart';
import '../repositories/auth_repository.dart';

class AutenticarProvedorCloud {
  final AuthRepository _repository;

  const AutenticarProvedorCloud(this._repository);

  Future<Either<Failure, Unit>> call(CloudProvider provider) {
    return _repository.iniciarLogin(provider);
  }
}
