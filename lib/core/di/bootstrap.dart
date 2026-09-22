import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../features/certificate_capture/data/local/certificate_local_store.dart';
import '../../features/cloud_sync/data/local/upload_queue_local_store.dart';
import '../../features/comprovantes/data/local/comprovante_local_store.dart';
import '../../features/dossie_builder/data/local/dossie_local_store.dart';
import '../../features/lattes_parser/data/local/curriculo_local_store.dart';

/// Abre as Hive boxes (IndexedDB no web) ANTES do primeiro frame — requisito
/// de "retomável após recarga de aba" (ver `main.dart`).
Future<void> bootstrap() async {
  await Hive.initFlutter();
  // As boxes são independentes entre si — abrir em paralelo em vez de
  // sequencialmente evita somar round-trips de IndexedDB no cold start
  // (achado da 2ª revisão de código).
  await Future.wait([
    Hive.openBox<Map>(CertificateLocalStore.metadataBoxName),
    Hive.openBox<Uint8List>(CertificateLocalStore.imagesBoxName),
    Hive.openBox<Map>(UploadQueueLocalStore.metadataBoxName),
    Hive.openBox<Uint8List>(UploadQueueLocalStore.pdfsBoxName),
    Hive.openBox<Map>(DossieLocalStore.dossieBoxName),
    Hive.openBox<Map>(DossieLocalStore.editalBoxName),
    Hive.openBox<Uint8List>(DossieLocalStore.pdfFinalBoxName),
    Hive.openBox<Map>(CurriculoLocalStore.boxName),
    Hive.openBox<Map>(ComprovanteLocalStore.metadataBoxName),
    Hive.openBox<Uint8List>(ComprovanteLocalStore.bytesBoxName),
  ]);
}
