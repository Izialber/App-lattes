import 'package:equatable/equatable.dart';

/// Falhas de domínio. Nenhuma camada acima de `data/` deve conhecer exceções
/// de infraestrutura (FormatException, DioException, XmlParserException...);
/// toda exceção de infraestrutura é capturada em `data/` e traduzida para uma
/// destas subclasses antes de subir para `domain`/`presentation`.
sealed class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

/// XML do Lattes malformado além do que o parser defensivo tolera (ex.: não é
/// XML válido, ou não é um XML de currículo Lattes reconhecível).
class LattesParseFailure extends Failure {
  const LattesParseFailure(super.message);
}

/// Falha ao capturar/comprimir/converter uma imagem de certificado.
class CaptureFailure extends Failure {
  const CaptureFailure(super.message);
}

/// Falha de comunicação com a API de LLM (rede, quota, resposta fora do
/// schema esperado, chave BYOK ausente ou inválida).
class LlmFailure extends Failure {
  final bool isQuotaOrAuth;
  const LlmFailure(super.message, {this.isQuotaOrAuth = false});

  @override
  List<Object?> get props => [message, isQuotaOrAuth];
}

/// Falha de autenticação OAuth2 (token expirado sem refresh válido, PKCE
/// inválido, usuário negou consentimento).
class AuthFailure extends Failure {
  final bool requiresReauth;
  const AuthFailure(super.message, {this.requiresReauth = false});

  @override
  List<Object?> get props => [message, requiresReauth];
}

/// Falha de upload/leitura no Google Drive ou Microsoft Graph. `isTransient`
/// indica se a operação deve voltar para a fila offline-first com retry.
class CloudStorageFailure extends Failure {
  final bool isTransient;
  const CloudStorageFailure(super.message, {this.isTransient = true});

  @override
  List<Object?> get props => [message, isTransient];
}

/// Falha ao montar o dossiê (merge de PDF, extração de critérios do edital).
class DossieFailure extends Failure {
  const DossieFailure(super.message);
}

/// O dispositivo/navegador não tem memória estimada suficiente para concluir
/// a operação. Não é um erro do usuário: é o sinal para a UI mostrar a
/// "degradação explícita" (ex.: pedir para concluir no desktop) em vez de
/// deixar a aba travar.
class InsufficientDeviceMemoryFailure extends Failure {
  final int estimatedBytesNeeded;
  final int estimatedBytesAvailable;
  const InsufficientDeviceMemoryFailure(
    super.message, {
    required this.estimatedBytesNeeded,
    required this.estimatedBytesAvailable,
  });

  @override
  List<Object?> get props => [message, estimatedBytesNeeded, estimatedBytesAvailable];
}

/// Storage local (IndexedDB/Hive) indisponível ou foi limpo pelo navegador
/// (ver RISCOS.md: PWA não instalado -> IndexedDB pode expirar em 7 dias).
class LocalStorageFailure extends Failure {
  final bool likelyEvicted;
  const LocalStorageFailure(super.message, {this.likelyEvicted = false});

  @override
  List<Object?> get props => [message, likelyEvicted];
}
