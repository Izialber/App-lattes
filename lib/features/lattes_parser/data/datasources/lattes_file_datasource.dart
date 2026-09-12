/// Obtém o conteúdo textual do XML a partir da fonte escolhida pelo usuário
/// — seletor de arquivo nativo no celular, ou seletor/drag&drop no desktop.
/// Ambas as fontes convergem para o mesmo retorno (`String` com o conteúdo
/// do arquivo), que é o que `LattesRepository.parseXmlContent` espera —
/// a unificação das duas fontes de entrada é responsabilidade desta classe,
/// não da camada de apresentação.
///
/// PENDENTE (fora do escopo do entregável 5 — o parser em si está completo
/// e testado): implementação via `file_picker` (`FilePicker.platform.pickFiles`
/// com `withData: true` para obter bytes diretamente no web, decodificados
/// como UTF-8; XML do Lattes é sempre UTF-8 ou ISO-8859-1 — detectar BOM/
/// declaração de encoding no XML antes de decodificar, para não corromper
/// acentuação de nomes e títulos).
abstract class LattesFileDatasource {
  Future<String> lerConteudoComoTexto();
}
