import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../features/certificate_capture/data/local/certificate_local_store.dart';
import '../../features/cloud_sync/data/local/upload_queue_local_store.dart';

/// Abre as Hive boxes (IndexedDB no web) ANTES do primeiro frame — requisito
/// de "retomável após recarga de aba" (ver `main.dart`). Só abre o que já
/// tem uma implementação real de repositório por trás: o estado de dossiê em
/// montagem (módulo 4) continua sem Hive box própria enquanto a camada de
/// dados desse módulo for stub — abrir a box antes de existir quem escreva
/// nela seria trabalho morto.
Future<void> bootstrap() async {
  await Hive.initFlutter();
  await Hive.openBox<Map>(CertificateLocalStore.metadataBoxName);
  await Hive.openBox<Uint8List>(CertificateLocalStore.imagesBoxName);
  await Hive.openBox<Map>(UploadQueueLocalStore.metadataBoxName);
  await Hive.openBox<Uint8List>(UploadQueueLocalStore.pdfsBoxName);
}
