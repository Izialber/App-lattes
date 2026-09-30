import 'package:equatable/equatable.dart';

/// Um código de convite de uso único (ver DECISOES.md, "Códigos de
/// convite") — o próprio [codigo] é a chave de persistência no Firestore
/// (`codigos/{codigo}`), nunca reusado depois de [usado].
class CodigoAcesso extends Equatable {
  final String codigo;
  final bool usado;
  final DateTime criadoEm;
  final String? rotulo;
  final DateTime? usadoEm;
  final String? usadoPara;

  const CodigoAcesso({
    required this.codigo,
    required this.usado,
    required this.criadoEm,
    this.rotulo,
    this.usadoEm,
    this.usadoPara,
  });

  @override
  List<Object?> get props => [codigo, usado, criadoEm, rotulo, usadoEm, usadoPara];
}
