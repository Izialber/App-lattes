import '../../../../core/platform/camera/camera_service.dart';

/// Datasource fino sobre [CameraService]: converte [CapturedFrame] em bytes
/// crus que o repositório vai persistir e enviar ao LLM. Não faz nenhuma
/// regra de negócio — só adapta a abstração de plataforma para o formato
/// que `CertificateRepositoryImpl` espera.
///
/// PENDENTE (fora do escopo do entregável 5): implementar usando a instância
/// de `CameraService` injetada via `core/di/injection.dart`.
class CameraCaptureDatasource {
  final CameraService _cameraService;

  const CameraCaptureDatasource(this._cameraService);

  Future<CapturedFrame> capturar() {
    // TODO: delegar para _cameraService.captureFrame() após start() ter
    // sido chamado a partir do gesto do usuário na presentation layer.
    throw UnimplementedError('CameraCaptureDatasource.capturar: pendente (ver DECISOES.md)');
  }
}
