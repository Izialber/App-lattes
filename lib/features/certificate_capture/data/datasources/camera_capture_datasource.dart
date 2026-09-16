import '../../../../core/platform/camera/camera_service.dart';

/// Datasource fino sobre [CameraService]: converte [CapturedFrame] em bytes
/// crus que o repositório vai persistir e enviar ao LLM. Não faz nenhuma
/// regra de negócio — só adapta a abstração de plataforma para o formato
/// que `CertificateRepositoryImpl` espera. `start()` precisa ter sido
/// chamado pela presentation layer, a partir de um gesto do usuário, antes
/// de `capturar()` (ver docstring de [CameraService]).
class CameraCaptureDatasource {
  final CameraService _cameraService;

  const CameraCaptureDatasource(this._cameraService);

  Future<CapturedFrame> capturar() => _cameraService.captureFrame();
}
