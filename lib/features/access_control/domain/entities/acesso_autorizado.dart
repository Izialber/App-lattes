import 'package:equatable/equatable.dart';

/// Um e-mail que já resgatou um código de convite com sucesso — registro
/// criado pela mesma escrita que marca o código como usado (ver
/// `CodigoAcessoRepositoryImpl.resgatarCodigo`). NÃO é um histórico de
/// login: é o momento único em que esse e-mail ganhou acesso ao app, não
/// uma entrada por sessão/login (o app não registra isso — ver DECISOES.md).
class AcessoAutorizado extends Equatable {
  final String email;
  final DateTime autorizadoEm;
  final String codigoUsado;

  const AcessoAutorizado({
    required this.email,
    required this.autorizadoEm,
    required this.codigoUsado,
  });

  @override
  List<Object?> get props => [email, autorizadoEm, codigoUsado];
}
