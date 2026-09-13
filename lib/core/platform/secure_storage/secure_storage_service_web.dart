import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'secure_storage_service.dart';

/// Monta `{name: 'AES-GCM', ...}` como objeto JS de verdade (via
/// `dart:js_interop_unsafe`) em vez de `Map.jsify()`: os parâmetros de
/// algoritmo do Web Crypto às vezes carregam um `iv` que já é um
/// TypedArray JS (não um valor Dart puro), e `jsify()` não converte
/// corretamente um valor que já é JS embutido dentro de um Map.
JSObject _algoritmo(String name, {JSAny? iv, int? length}) {
  final obj = JSObject()..['name'] = name.toJS;
  if (iv != null) obj['iv'] = iv;
  if (length != null) obj['length'] = length.toJS;
  return obj;
}

const _dbName = 'certificados_lattes_secure';
const _dbVersion = 1;
const _keyStoreName = 'keys';
const _masterKeyId = 'master';
const _localStoragePrefix = 'certificados_lattes.secure.';

/// Implementação Web.
///
/// A chave AES-GCM é gerada como [web.CryptoKey] NÃO extraível
/// (`extractable: false`) e persistida no IndexedDB via structured clone —
/// o navegador permite guardar um `CryptoKey` diretamente (sem serializar
/// para bytes), então nenhum script (nem um XSS injetado na mesma origem)
/// consegue ler o material da chave: só pode pedir ao próprio navegador
/// para cifrar/decifrar usando o handle opaco.
///
/// Isso é deliberadamente diferente de `flutter_secure_storage_web`
/// (pacote de terceiros já usado no app para outros fins): ele cifra de
/// verdade, mas guarda a chave em texto puro no `localStorage` ao lado do
/// próprio conteúdo cifrado — o que anula a proteção contra o cenário que
/// mais importa aqui (XSS/DevTools). Por isso o SecureStorageService usa
/// esta implementação própria, não aquele pacote.
///
/// Só o texto cifrado (IV + ciphertext, já inúteis sem a chave) fica no
/// `localStorage`; a chave em si nunca sai do IndexedDB como bytes.
class SecureStorageServiceWeb implements SecureStorageService {
  Future<web.CryptoKey>? _masterKeyFuture;

  Future<web.CryptoKey> _getMasterKey() {
    return _masterKeyFuture ??= _loadOrCreateMasterKey();
  }

  Future<web.IDBDatabase> _openDatabase() {
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(_dbName, _dbVersion);

    request.onupgradeneeded = ((web.Event _) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_keyStoreName)) {
        db.createObjectStore(_keyStoreName);
      }
    }).toJS;
    request.onsuccess = ((web.Event _) {
      completer.complete(request.result as web.IDBDatabase);
    }).toJS;
    request.onerror = ((web.Event _) {
      completer.completeError(StateError('Falha ao abrir IndexedDB ($_dbName)'));
    }).toJS;

    return completer.future;
  }

  Future<JSAny?> _await(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) => completer.complete(request.result)).toJS;
    request.onerror = ((web.Event _) => completer.completeError(StateError('Falha na operação IndexedDB'))).toJS;
    return completer.future;
  }

  Future<web.CryptoKey> _loadOrCreateMasterKey() async {
    final db = await _openDatabase();
    final readTx = db.transaction(_keyStoreName.toJS, 'readonly');
    final existing = await _await(readTx.objectStore(_keyStoreName).get(_masterKeyId.toJS));
    if (existing != null) {
      return existing as web.CryptoKey;
    }

    final algorithm = _algoritmo('AES-GCM', length: 256);
    final usages = <JSString>['encrypt'.toJS, 'decrypt'.toJS].toJS;
    final newKey = await web.window.crypto.subtle.generateKey(algorithm, false, usages).toDart;

    final writeTx = db.transaction(_keyStoreName.toJS, 'readwrite');
    await _await(writeTx.objectStore(_keyStoreName).put(newKey!, _masterKeyId.toJS));

    return newKey as web.CryptoKey;
  }

  @override
  Future<void> write({required String key, required String value}) async {
    final cryptoKey = await _getMasterKey();

    final iv = web.window.crypto.getRandomValues(Uint8List(12).toJS);
    final algorithm = _algoritmo('AES-GCM', iv: iv);

    final plaintext = Uint8List.fromList(utf8.encode(value)).toJS;
    final encrypted = await web.window.crypto.subtle.encrypt(algorithm, cryptoKey, plaintext).toDart;
    final cipherBytes = (encrypted as JSArrayBuffer).toDart.asUint8List();
    final ivBytes = (iv as JSUint8Array).toDart;

    final encoded = '${base64Encode(ivBytes)}.${base64Encode(cipherBytes)}';
    web.window.localStorage.setItem('$_localStoragePrefix$key', encoded);
  }

  @override
  Future<String?> read({required String key}) async {
    final stored = web.window.localStorage.getItem('$_localStoragePrefix$key');
    if (stored == null) return null;

    final parts = stored.split('.');
    if (parts.length != 2) return null;

    final cryptoKey = await _getMasterKey();
    final iv = base64Decode(parts[0]);
    final cipherBytes = base64Decode(parts[1]);

    final algorithm = _algoritmo('AES-GCM', iv: iv.toJS);
    try {
      final decrypted =
          await web.window.crypto.subtle.decrypt(algorithm, cryptoKey, cipherBytes.toJS).toDart;
      return utf8.decode((decrypted as JSArrayBuffer).toDart.asUint8List());
    } catch (_) {
      // Chave do IndexedDB foi limpa pelo navegador sem o localStorage
      // correspondente (ou vice-versa): trata como ausente em vez de
      // propagar uma exceção de decifragem para o chamador.
      return null;
    }
  }

  @override
  Future<void> delete({required String key}) async {
    web.window.localStorage.removeItem('$_localStoragePrefix$key');
  }

  @override
  Future<void> clearAll() async {
    final keysToRemove = <String>[];
    for (var i = 0; i < web.window.localStorage.length; i++) {
      final k = web.window.localStorage.key(i);
      if (k != null && k.startsWith(_localStoragePrefix)) {
        keysToRemove.add(k);
      }
    }
    for (final k in keysToRemove) {
      web.window.localStorage.removeItem(k);
    }
  }
}
