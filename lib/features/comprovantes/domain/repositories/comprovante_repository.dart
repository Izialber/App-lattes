import 'dart:typed_data';

import 'package:fpdart/fpdart.dart' show Either, Unit;

import '../../../../core/error/failures.dart';
import '../entities/categoria_entrada_lattes.dart';
import '../entities/comprovante_entrada.dart';

abstract class ComprovanteRepository {
  /// Normaliza formato (HEIC -> JPEG quando aplicável) e anexa [bytes] como
  /// UM NOVO comprovante da entrada [entradaId] — uma entrada pode ter
  /// vários (ex.: diploma + histórico do mesmo curso), então isto nunca
  /// substitui um comprovante existente.
  Future<Either<Failure, ComprovanteEntrada>> anexar({
    required String entradaId,
    required CategoriaEntradaLattes categoria,
    required List<int> bytes,
    required String nomeArquivo,
    required String mimeType,
  });

  /// Remove UM comprovante específico por [comprovanteId] (não por
  /// `entradaId` — várias entradas podem ter o mesmo `entradaId`).
  Future<Either<Failure, Unit>> remover(String comprovanteId);

  /// Todos os comprovantes já anexados — a UI agrupa por `entradaId` para
  /// decidir o status de cada `EntradaLattesRef` e listar seus anexos.
  Future<List<ComprovanteEntrada>> listarTodos();

  Uint8List? lerBytes(String comprovanteId);

  /// Atualiza o status de sincronização com o Drive (mesmo padrão de
  /// `CertificateRepository.atualizarStatus`) — usado por
  /// `ComprovantesSyncController` (`cloud_sync`).
  Future<Either<Failure, Unit>> atualizarStatusSincronizacao(
    String comprovanteId,
    StatusSincronizacaoComprovante status, {
    String? idArquivoCloud,
    String? mensagemErro,
  });
}
