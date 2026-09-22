# Fluxo de Spec-Driven Development do Projeto

## 1. Estrutura de artefatos

* **`docs/superpowers/PRD.md`** — intenção de produto (problema, público, fora de escopo, critério de "pronto"). Estável, revisado no lugar — não é log, não append-only.
* **`docs/superpowers/specs/[data]-[slug]-design.md`** — spec + design fundidos (WHAT + HOW), um arquivo por feature/mudança.
* **`docs/superpowers/plans/[data]-[slug].md`** — breakdown executável de tasks, referencia o spec correspondente via campo `**Spec:**`.
* **`docs/superpowers/specs/README.md`** — índice de todas as specs, mantido atualizado a cada nova spec criada.
* **`docs/superpowers/ADR.md`** — log append-only de decisões de nível de projeto (`AD-NNN`).
* **`HANDOFF.md`** (raiz) — snapshot de pausa/retomada da sessão em andamento; sobrescrito a cada handoff, não é histórico.

## 2. Quando registrar uma decisão em `ADR.md`

Uma decisão só vira entrada `AD-NNN` se passar nos três critérios simultaneamente:

1. **Difícil de reverter** — mudar de rumo depois carrega custo real.
2. **Surpreendente sem contexto** — um leitor futuro olharia o resultado e perguntaria "por que fizeram assim?".
3. **Produto de um trade-off real** — havia alternativa genuína e uma escolha deliberada foi feita.

Se faltar qualquer um dos três, a decisão fica registrada apenas na seção correspondente do `-design.md` da própria feature — não vira `AD-NNN`.

## 3. Numeração e escrita em `ADR.md`

* `AD-NNN` é sequencial, nunca reutilizado.
* Nunca editar ou apagar uma entrada antiga. Para substituir uma decisão, crie uma nova `AD-NNN` e marque a antiga como `superseded by AD-NNN`.

## 4. Índice de specs

Toda nova spec criada em `docs/superpowers/specs/` ganha uma linha em `specs/README.md` (data, nome, status, plano relacionado) na mesma sessão em que a spec é criada.

## 5. Rastreabilidade leve de requisitos

`-design.md` de features não-triviais inclui uma tabela `## Requisitos rastreados` (ID curto, requisito em uma frase, task correspondente em `plans/*.md`, status). Não é obrigatória notação EARS formal — o objetivo é permitir localizar rapidamente qual task resolve qual requisito.

## 6. Não sobreposição com `HANDOFF.md`

`ADR.md` nunca guarda snapshot de sessão em andamento — isso é papel exclusivo do `HANDOFF.md` na raiz. `ADR.md` é só o log permanente de decisões de projeto.

## 7. Padrão de formatação (specs e plans)

**Toda spec (`docs/superpowers/specs/*-design.md`) começa com:**

```markdown
# <Nome da Feature> — Especificação de Design

**Data:** YYYY-MM-DD  
**Status:** <um dos status listados em `specs/README.md`>  
**Branch Alvo:** `nome-da-branch`
```

As seções do corpo são numeradas sequencialmente (`## 1. Contexto`, `## 2. Objetivo`, ...).

Toda spec não-trivial inclui uma seção `## Alternativas consideradas e por que foram descartadas` — lista as abordagens alternativas cogitadas e o motivo de cada uma ter sido rejeitada, antes de descrever a escolhida em `## Decisão`/`## Design`. É o papel que um RFC cumpriria num time — aqui, vira uma seção da própria spec em vez de artefato separado, já que não há debate multi-pessoa a coordenar.

**Todo plano (`docs/superpowers/plans/*.md`) começa com:**

```markdown
# <Nome da Feature> — Plano de Implementação

> **Para executores agenticos:** use a skill de execução de plano do seu setup (ex.: `superpowers:subagent-driven-development` ou `superpowers:executing-plans`) para implementar tarefa por tarefa. As etapas usam checkbox (`- [ ]`) para rastreamento.

**Objetivo:** ...
**Arquitetura:** ...
**Stack Tecnológica:** ...
**Spec:** `caminho/para/o/-design.md`
**Branch de Trabalho:** `nome-da-branch`

## Global Constraints
```

Tasks usam `### Task N: <Nome>`, sempre com blocos `**Files:**` e `**Interfaces:**` antes dos steps numerados.
