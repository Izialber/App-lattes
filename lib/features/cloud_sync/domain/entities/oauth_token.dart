import 'package:equatable/equatable.dart';

import 'cloud_provider.dart';

/// Par de tokens OAuth2 (PKCE, sem client secret). `expiraEm` é sempre
/// verificado com uma margem de segurança (`AppConstants.tokenRefreshMargin`)
/// antes de qualquer chamada de API, nunca só no momento em que a API
/// retorna 401 — isso evita perder uma operação de upload em andamento.
class OAuthToken extends Equatable {
  final CloudProvider provider;
  final String accessToken;
  final String refreshToken;
  final DateTime expiraEm;

  const OAuthToken({
    required this.provider,
    required this.accessToken,
    required this.refreshToken,
    required this.expiraEm,
  });

  bool get precisaRenovar =>
      DateTime.now().isAfter(expiraEm.subtract(const Duration(minutes: 5)));

  @override
  List<Object?> get props => [provider, accessToken, refreshToken, expiraEm];
}
