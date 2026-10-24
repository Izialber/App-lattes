import 'package:flutter_test/flutter_test.dart';

import 'package:certificados_lattes/features/comprovantes/domain/entities/categoria_entrada_lattes.dart';
import 'package:certificados_lattes/features/comprovantes/domain/entities/entrada_lattes_ref.dart';
import 'package:certificados_lattes/features/comprovantes/domain/entities/sugerir_entrada_por_nome.dart';

const _engenharia = EntradaLattesRef(
  id: 'eng',
  categoria: CategoriaEntradaLattes.curso,
  titulo: 'Engenharia Elétrica',
  subtitulo: 'Universidade Estácio de Sá · 2010–2015',
);
const _fisica = EntradaLattesRef(
  id: 'fis',
  categoria: CategoriaEntradaLattes.curso,
  titulo: 'Licenciatura em Física',
  subtitulo: 'Universidade X · 2016–2019',
);
const _matematica = EntradaLattesRef(
  id: 'mat',
  categoria: CategoriaEntradaLattes.curso,
  titulo: 'Licenciatura em Matemática',
  subtitulo: 'Universidade X · 2016–2020',
);
const _fenep = EntradaLattesRef(
  id: 'fenep',
  categoria: CategoriaEntradaLattes.participacaoEvento,
  titulo: '7º Congresso Nacional FENEP',
  subtitulo: '2019',
);
const _ingles = EntradaLattesRef(
  id: 'ingles',
  categoria: CategoriaEntradaLattes.idioma,
  titulo: 'Inglês',
  subtitulo: 'Leitura: Bem',
);

const _entradas = [_engenharia, _fisica, _matematica, _fenep, _ingles];

void main() {
  group('palavrasSignificativas', () {
    test('tira acento, caixa, extensão e palavras genéricas de certificado', () {
      expect(
        palavrasSignificativas('Certificado_Engenharia-ELÉTRICA.pdf'),
        {'engenharia', 'eletrica'},
      );
    });

    test('mantém números curtos (ano, edição)', () {
      expect(palavrasSignificativas('7 congresso 2019'), {'7', 'congresso', '2019'});
    });
  });

  group('sugerirEntradaPorNome', () {
    test('liga pelo título mesmo com acento e caixa diferentes', () {
      expect(
        sugerirEntradaPorNome('Diplomas/Engenharia Elétrica/Engenharia Elétrica.pdf', _entradas),
        'eng',
      );
    });

    test('usa as palavras da subpasta junto com o nome', () {
      expect(
        sugerirEntradaPorNome('Diplomas/fisica/historico_LICENCIATURA EM FÍSIC.pdf', _entradas),
        'fis',
      );
    });

    test('distingue duas entradas que dividem uma palavra (licenciatura)', () {
      expect(
        sugerirEntradaPorNome('Diploma_ LICENCIATURA EM MATEMÁTICA .pdf', _entradas),
        'mat',
      );
    });

    test('nome de arquivo longo e com sublinhados ainda bate', () {
      expect(
        sugerirEntradaPorNome(
          'Eventos/certificado_7_congresso_nacional_fenep_1_edicao_izialber_muniz.pdf',
          _entradas,
        ),
        'fenep',
      );
    });

    test('título de uma palavra só basta com 1 palavra em comum', () {
      expect(sugerirEntradaPorNome('Certificado Inglês avançado.pdf', _entradas), 'ingles');
    });

    test('só 1 palavra em comum com título de várias = sem entrada (não chuta)', () {
      expect(sugerirEntradaPorNome('Licenciatura.pdf', _entradas), isNull);
    });

    test('arquivo sem relação nenhuma = sem entrada', () {
      expect(sugerirEntradaPorNome('Premiações/CEO Award.pdf', _entradas), isNull);
    });

    test('instituição sozinha nunca decide', () {
      expect(sugerirEntradaPorNome('Universidade Estácio de Sá.pdf', _entradas), isNull);
    });

    test('empate entre duas entradas = sem entrada', () {
      const a = EntradaLattesRef(
        id: 'a',
        categoria: CategoriaEntradaLattes.formacaoComplementar,
        titulo: 'Segurança de Redes',
        subtitulo: '',
      );
      const b = EntradaLattesRef(
        id: 'b',
        categoria: CategoriaEntradaLattes.formacaoComplementar,
        titulo: 'Redes de Segurança',
        subtitulo: '',
      );
      expect(sugerirEntradaPorNome('seguranca redes.pdf', [a, b]), isNull);
    });

    test('instituição desempata quando o título empata', () {
      const a = EntradaLattesRef(
        id: 'a',
        categoria: CategoriaEntradaLattes.formacaoComplementar,
        titulo: 'Cybersecurity Essentials',
        subtitulo: 'Cisco Max',
      );
      const b = EntradaLattesRef(
        id: 'b',
        categoria: CategoriaEntradaLattes.formacaoComplementar,
        titulo: 'Cybersecurity Essentials',
        subtitulo: 'UFRN',
      );
      expect(sugerirEntradaPorNome('UFRN - Cybersecurity Essentials.pdf', [a, b]), 'b');
    });

    test('lista de entradas vazia = sem entrada', () {
      expect(sugerirEntradaPorNome('Engenharia Elétrica.pdf', const []), isNull);
    });
  });
}
