/// Abstração de detecção de conectividade, usada pela fila offline-first do
/// módulo de sincronização cloud para decidir quando tentar drenar a fila.
///
/// No Safari iOS os eventos de `connectivity_plus` são menos granulares
/// (ver RISCOS.md); por isso o `CloudStorageRepositoryImpl` NUNCA depende
/// exclusivamente deste stream — o próprio erro de rede do Dio ao tentar
/// enviar é sempre um segundo sinal de "estou offline, enfileirar".
abstract class ConnectivityGate {
  Stream<bool> get onConnectivityChanged; // true = online
  Future<bool> get isOnlineNow;
}
