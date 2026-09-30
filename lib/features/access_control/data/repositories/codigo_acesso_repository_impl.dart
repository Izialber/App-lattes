import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right, Unit, unit;

import '../../../../core/error/failures.dart';
import '../../domain/entities/codigo_acesso.dart';
import '../../domain/repositories/codigo_acesso_repository.dart';

const _colecaoCodigos = 'codigos';
const _colecaoAcessos = 'acessos_autorizados';

/// Sem caracteres ambíguos (0/O, 1/I/L) — o código é digitado à mão por
/// quem recebe o convite.
const _alfabeto = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

class CodigoAcessoRepositoryImpl implements CodigoAcessoRepository {
  final FirebaseFirestore _db;
  final Random _random;

  CodigoAcessoRepositoryImpl({FirebaseFirestore? db, Random? random})
      : _db = db ?? FirebaseFirestore.instance,
        _random = random ?? Random.secure();

  String _gerarCodigo() =>
      List.generate(8, (_) => _alfabeto[_random.nextInt(_alfabeto.length)]).join();

  CodigoAcesso _daSnapshot(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final dados = doc.data();
    return CodigoAcesso(
      codigo: doc.id,
      usado: dados['usado'] as bool? ?? false,
      criadoEm: (dados['criadoEm'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rotulo: dados['rotulo'] as String?,
      usadoEm: (dados['usadoEm'] as Timestamp?)?.toDate(),
      usadoPara: dados['usadoPara'] as String?,
    );
  }

  @override
  Future<Either<Failure, Unit>> resgatarCodigo({
    required String codigo,
    required String identificador,
  }) async {
    final codigoNormalizado = codigo.trim().toUpperCase();
    // E-mail em minúsculas — sem isso, o mesmo e-mail com capitalização
    // diferente entre sessões (ex.: Google vs. o que o usuário digitou no
    // formulário) criaria dois registros `acessos_autorizados` distintos
    // pro mesmo dono, e `emailAutorizado` deixaria de achar o já existente.
    final identificadorNormalizado = identificador.trim().toLowerCase();
    if (codigoNormalizado.isEmpty) {
      return const Left(AccessCodeFailure('Digite um código.'));
    }

    try {
      final ref = _db.collection(_colecaoCodigos).doc(codigoNormalizado);

      // Transação: garante que dois resgates simultâneos do mesmo código
      // não passem os dois — o segundo sempre vê `usado: true` já gravado
      // pelo primeiro (ver DECISOES.md, "Códigos de convite").
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) {
          throw const AccessCodeFailure('Código inválido.');
        }
        if (snap.data()?['usado'] == true) {
          throw const AccessCodeFailure('Este código já foi utilizado.');
        }
        tx.update(ref, {
          'usado': true,
          'usadoEm': FieldValue.serverTimestamp(),
          'usadoPara': identificadorNormalizado,
        });
      });

      // Só funcionalmente necessário pro fluxo Google (lembrar que este
      // e-mail já passou pelo código, ver `emailAutorizado`) — inofensivo
      // gravar também no fluxo e-mail/senha, que simplesmente não lê isto.
      await _db.collection(_colecaoAcessos).doc(identificadorNormalizado).set({
        'email': identificadorNormalizado,
        'autorizadoEm': FieldValue.serverTimestamp(),
        'codigoUsado': codigoNormalizado,
      });

      return const Right(unit);
    } on AccessCodeFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(AccessCodeFailure('Falha ao resgatar código: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> emailAutorizado(String email) async {
    try {
      final doc = await _db.collection(_colecaoAcessos).doc(email.trim().toLowerCase()).get();
      return Right(doc.exists);
    } catch (e) {
      return Left(AccessCodeFailure('Falha ao checar autorização: $e'));
    }
  }

  @override
  Future<Either<Failure, List<CodigoAcesso>>> listarCodigos() async {
    try {
      final snap =
          await _db.collection(_colecaoCodigos).orderBy('criadoEm', descending: true).get();
      return Right(snap.docs.map(_daSnapshot).toList());
    } catch (e) {
      return Left(AccessCodeFailure('Falha ao listar códigos: $e'));
    }
  }

  @override
  Future<Either<Failure, CodigoAcesso>> criarCodigo({String? rotulo}) async {
    try {
      // Regenerar em caso de colisão (espaço de 32^8 combinações — nunca
      // deve colidir na prática, só por segurança).
      String codigo;
      DocumentReference<Map<String, dynamic>> ref;
      do {
        codigo = _gerarCodigo();
        ref = _db.collection(_colecaoCodigos).doc(codigo);
      } while ((await ref.get()).exists);

      await ref.set({
        'usado': false,
        'criadoEm': FieldValue.serverTimestamp(),
        if (rotulo != null && rotulo.isNotEmpty) 'rotulo': rotulo,
      });

      return Right(CodigoAcesso(codigo: codigo, usado: false, criadoEm: DateTime.now(), rotulo: rotulo));
    } catch (e) {
      return Left(AccessCodeFailure('Falha ao criar código: $e'));
    }
  }

  @override
  Future<Either<Failure, Unit>> revogarCodigo(String codigo) async {
    try {
      final ref = _db.collection(_colecaoCodigos).doc(codigo);
      final snap = await ref.get();
      if (snap.exists && snap.data()?['usado'] == true) {
        return const Left(AccessCodeFailure('Um código já usado não pode ser revogado.'));
      }
      await ref.delete();
      return const Right(unit);
    } catch (e) {
      return Left(AccessCodeFailure('Falha ao revogar código: $e'));
    }
  }
}
