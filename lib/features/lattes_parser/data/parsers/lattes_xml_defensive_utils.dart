import 'package:xml/xml.dart';

/// Utilidades de leitura defensiva do XML do Lattes (formato CNPq).
///
/// Regra de ouro deste arquivo: NENHUMA função aqui lança exceção por causa
/// de um nó ausente, um atributo ausente, ou um valor mal formatado. Tudo
/// que não pode ser lido com segurança retorna `null` (ou lista vazia), e a
/// decisão do que fazer com essa ausência é do chamador (no nosso caso,
/// sempre "omitir o campo", nunca "inventar um valor").

/// Lê um atributo de forma segura. Trata `element == null` (nó ausente),
/// atributo ausente, e atributo presente mas vazio/só espaços — todos os
/// três casos retornam `null`, nunca lançam.
String? attrOrNull(XmlElement? element, String name) {
  if (element == null) return null;
  final value = element.getAttribute(name);
  if (value == null) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Lê um atributo inteiro de forma segura. Valores não numéricos (ex.: um
/// XML de terceiros com "N/A" em ANO-DE-INICIO) retornam `null` em vez de
/// lançar `FormatException`.
int? intAttrOrNull(XmlElement? element, String name) {
  final raw = attrOrNull(element, name);
  if (raw == null) return null;
  return int.tryParse(raw);
}

/// Retorna o primeiro filho direto com a tag [name], ou `null` se [parent`
/// for nulo ou não tiver esse filho. Nunca lança mesmo se [parent] for nulo
/// — isso é o que permite encadear chamadas como
/// `findChild(findChild(raiz, 'A'), 'B')` sem checagem de nulidade manual em
/// cada passo.
XmlElement? findChild(XmlElement? parent, String name) {
  if (parent == null) return null;
  final matches = parent.findElements(name);
  return matches.isEmpty ? null : matches.first;
}

/// Retorna todos os filhos diretos com a tag [name]. Lista vazia (nunca
/// null) quando [parent] é nulo ou não tem esse filho — permite `for (...)`
/// direto sem checagem de nulidade.
List<XmlElement> findChildren(XmlElement? parent, String name) {
  if (parent == null) return const [];
  return parent.findElements(name).toList(growable: false);
}

/// Datas do Lattes aparecem como atributos separados de mês/ano (ex.:
/// `MES-DE-INICIO="03" ANO-DE-INICIO="2020"`), e o mês é frequentemente
/// omitido pelo usuário mesmo quando o ano está preenchido. Quando o ANO
/// está ausente, não existe data — nunca inventamos "01/01" como padrão
/// silencioso; quando só o MÊS está ausente, assumimos janeiro (mês 1) de
/// forma explícita e documentada aqui, para permitir ordenação cronológica
/// aproximada sem perder o registro.
DateTime? dateFromMonthYearAttrs(
  XmlElement? element, {
  required String anoAttr,
  String? mesAttr,
}) {
  final ano = intAttrOrNull(element, anoAttr);
  if (ano == null) return null;
  final mesLido = mesAttr != null ? intAttrOrNull(element, mesAttr) : null;
  final mes = (mesLido != null && mesLido >= 1 && mesLido <= 12) ? mesLido : 1;
  try {
    return DateTime(ano, mes);
  } catch (_) {
    return null;
  }
}

/// `DATA-ATUALIZACAO` do currículo Lattes vem como uma string de 8 dígitos
/// no formato `DDMMAAAA`, sem separadores (ex.: "07092026" = 7/9/2026).
/// Qualquer string fora desse padrão exato (tamanho diferente, não numérica,
/// dia/mês fora de faixa) retorna `null` em vez de lançar.
DateTime? parseDataAtualizacaoCv(String? raw) {
  if (raw == null) return null;
  final digitos = raw.trim();
  if (digitos.length != 8 || int.tryParse(digitos) == null) return null;

  final dia = int.tryParse(digitos.substring(0, 2));
  final mes = int.tryParse(digitos.substring(2, 4));
  final ano = int.tryParse(digitos.substring(4, 8));
  if (dia == null || mes == null || ano == null) return null;
  if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;

  try {
    return DateTime(ano, mes, dia);
  } catch (_) {
    return null;
  }
}
