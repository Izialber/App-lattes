import 'package:equatable/equatable.dart';

import 'vinculo_aprovado.dart';

enum StatusDossie {
  aguardandoRevisaoHumana,
  prontoParaCompilar,
  compilando,

  /// Compilação dividida em lotes porque o dossiê inteiro não cabe de uma
  /// vez no teto de memória do dispositivo (ver `DecidirEstrategiaDeMemoria`
  /// e RISCOS.md, "Memória no Safari iOS") — `loteAtual`/`totalDeLotes` no
  /// [Dossie] indicam o progresso para a UI mostrar uma barra de progresso
  /// em vez de uma barra indeterminada.
  compilandoEmPartes,
  compilado,

  /// Só ocorre quando nem o maior certificado isolado cabe no teto de
  /// memória do dispositivo atual (ver [EstrategiaMesclagemDossie.
  /// inviavelNoDispositivo]) — processamento em partes NÃO resolve esse
  /// caso, por decisão explícita do usuário de só usar este status como
  /// último recurso.
  degradadoAguardandoDesktop,
  falhaCompilacao,
}

/// Estado persistido do dossiê em montagem — precisa sobreviver a reload de
/// aba e a troca de dispositivo dentro do mesmo fluxo (ex.: usuário começa no
/// celular, sistema degrada explicitamente e pede para concluir no desktop).
class Dossie extends Equatable {
  final String id;
  final String editalId;
  final StatusDossie status;
  final List<VinculoAprovado> vinculosRevisados;
  final String? caminhoPdfFinal;
  final String? mensagemDegradacao;

  /// Nota informativa sobre um dossiê compilado com SUCESSO (ex.: contagem
  /// de certificados PDF-de-origem excluídos da mesclagem automática) — não
  /// é degradação (nenhum problema de memória ocorreu). Campo separado de
  /// [mensagemDegradacao] de propósito: um consumidor futuro que checar
  /// `mensagemDegradacao != null` para detectar degradação real de memória
  /// não pode ter falso positivo vindo de uma compilação comum que só
  /// excluiu alguns PDFs (achado da 2ª revisão de código).
  final String? notaCompilacao;

  /// Progresso da compilação em partes (ambos 0 quando não se aplica).
  /// `loteAtual` é 1-based para exibição direta na UI ("lote 2 de 5").
  final int loteAtual;
  final int totalDeLotes;

  const Dossie({
    required this.id,
    required this.editalId,
    required this.status,
    this.vinculosRevisados = const [],
    this.caminhoPdfFinal,
    this.mensagemDegradacao,
    this.notaCompilacao,
    this.loteAtual = 0,
    this.totalDeLotes = 0,
  });

  Dossie copyWith({
    StatusDossie? status,
    List<VinculoAprovado>? vinculosRevisados,
    String? caminhoPdfFinal,
    String? mensagemDegradacao,
    bool limparMensagemDegradacao = false,
    String? notaCompilacao,
    bool limparNotaCompilacao = false,
    int? loteAtual,
    int? totalDeLotes,
  }) {
    return Dossie(
      id: id,
      editalId: editalId,
      status: status ?? this.status,
      vinculosRevisados: vinculosRevisados ?? this.vinculosRevisados,
      caminhoPdfFinal: caminhoPdfFinal ?? this.caminhoPdfFinal,
      mensagemDegradacao: limparMensagemDegradacao
          ? null
          : (mensagemDegradacao ?? this.mensagemDegradacao),
      notaCompilacao: limparNotaCompilacao ? null : (notaCompilacao ?? this.notaCompilacao),
      loteAtual: loteAtual ?? this.loteAtual,
      totalDeLotes: totalDeLotes ?? this.totalDeLotes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        editalId,
        status,
        vinculosRevisados,
        caminhoPdfFinal,
        mensagemDegradacao,
        notaCompilacao,
        loteAtual,
        totalDeLotes,
      ];
}
