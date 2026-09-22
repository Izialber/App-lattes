import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:equatable/equatable.dart';

import 'categoria_entrada_lattes.dart';

/// Referência leve a UM item do currículo Lattes (um curso, uma publicação
/// etc.) — nunca persistida por si só. É recalculada a partir do
/// `CurriculoLattes` (via [gerarEntradasLattes]) toda vez que a tela de
/// comprovantes é montada; só o [id] é usado como chave de persistência
/// (ver `ComprovanteEntrada`).
class EntradaLattesRef extends Equatable {
  final String id;
  final CategoriaEntradaLattes categoria;
  final String titulo;
  final String subtitulo;

  const EntradaLattesRef({
    required this.id,
    required this.categoria,
    required this.titulo,
    required this.subtitulo,
  });

  @override
  List<Object?> get props => [id, categoria, titulo, subtitulo];
}

/// Nenhuma entidade do Lattes (`Curso`, `Publicacao` etc.) tem id — todas são
/// `Equatable` por valor (ver `lattes_parser/domain/entities/*.dart`). Este
/// id é derivado por hash dos campos que identificam a entrada dentro da
/// categoria, prefixado pelo nome da categoria (evita colisão entre
/// categorias diferentes que por acaso tenham o mesmo texto-base).
///
/// Estável entre reimportações do MESMO XML (mesmos campos -> mesmo hash),
/// mas NÃO sobrevive à edição de um campo identificador seguida de
/// reexportação — isso é uma limitação aceita conscientemente (ver
/// DECISOES.md): o comprovante antigo não é perdido, só fica "órfão" (ver
/// `ComprovantesLattesPage._secaoOrfaos`, que compara os ids salvos contra
/// os ids das entradas atuais).
String gerarIdEntrada(CategoriaEntradaLattes categoria, List<Object?> camposIdentificadores) {
  final normalizados = camposIdentificadores.map((campo) {
    if (campo == null) return '';
    return campo.toString().trim().toLowerCase();
  }).join('|');
  final chave = '${categoria.name}|$normalizados';
  final digest = crypto.sha256.convert(utf8.encode(chave));
  return digest.toString().substring(0, 24);
}
