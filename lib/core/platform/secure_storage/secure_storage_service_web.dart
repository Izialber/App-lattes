import 'secure_storage_service.dart';

/// Implementação Web.
///
/// `flutter_secure_storage` não tem binding confiável para web (cai para
/// `window.localStorage` sem cifrar, o que é inaceitável para tokens OAuth e
/// chave de LLM). Implementação real (pendente, listada em DECISOES.md):
///
/// 1. Gera (ou recupera) uma `CryptoKey` AES-GCM NÃO exportável via Web
///    Crypto API (`window.crypto.subtle.generateKey`), persistida como
///    `CryptoKey` opaca dentro do próprio IndexedDB (a API permite guardar
///    o objeto `CryptoKey`, não os bytes da chave — por isso ela nunca é
///    extraível mesmo por outro script na mesma origem).
/// 2. Cifra o valor com essa chave antes de gravar no Hive/IndexedDB.
/// 3. Decifra na leitura; falha de decifragem (ex.: IndexedDB parcialmente
///    limpo pelo navegador) é tratada como [LocalStorageFailure] com
///    `likelyEvicted: true`, disparando novo fluxo de login/BYOK.
///
/// Risco residual documentado em RISCOS.md: mesmo cifrado, o conteúdo é
/// perdido se o navegador limpar o IndexedDB (Safari: 7 dias sem uso do PWA
/// instalado). Isso é aceitável para tokens (basta re-autenticar), mas exige
/// aviso explícito ao usuário para a chave BYOK do LLM.
class SecureStorageServiceWeb implements SecureStorageService {
  @override
  Future<void> write({required String key, required String value}) async {
    throw UnimplementedError(
      'SecureStorageServiceWeb.write: cifragem via Web Crypto pendente (ver DECISOES.md)',
    );
  }

  @override
  Future<String?> read({required String key}) async {
    throw UnimplementedError(
      'SecureStorageServiceWeb.read: decifragem via Web Crypto pendente (ver DECISOES.md)',
    );
  }

  @override
  Future<void> delete({required String key}) async {
    throw UnimplementedError('SecureStorageServiceWeb.delete: pendente (ver DECISOES.md)');
  }

  @override
  Future<void> clearAll() async {
    throw UnimplementedError('SecureStorageServiceWeb.clearAll: pendente (ver DECISOES.md)');
  }
}
