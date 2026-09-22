---
name: novo-projeto
description: Cria a estrutura de pastas padrao (cross-agent .agents/ + entrypoints por agente escolhido + PRD/ADR/specs/plans do SDD Superpowers em docs/ + .editorconfig por linguagem) para um projeto novo. So invocado manualmente via /novo-projeto.
disable-model-invocation: true
arguments: [nome]
---

# Novo Projeto

Antes de rodar o script, se nao tiver ficado claro na conversa, pergunte ao usuario:

1. **Stack completa** — linguagens/frameworks do projeto. Mapeia pra `--lang`:
   `java`, `python`, `web` (JS/TS/JSX/TSX/HTML/CSS/JSON), `go`, `yaml`, `markdown`,
   `csharp`, `php`, `kotlin`, `rust`, `ruby`. Pode ser mais de uma (ex.: `go,web`
   pra back-end Go + front-end React). Se nao souber ainda, pode omitir a flag
   (o `.editorconfig` sai so com a secao `[*]` base).

2. **Agente(s) de IA que vai usar** — mapeia pra `--agents`:
   `claude` (gera `CLAUDE.md` + `.claude/` com rules symlinked, settings.json,
   skills/agents vazios), `grok`/`codex`/`cursor` (todos leem o mesmo `AGENTS.md`
   na raiz — padrao aberto agents.md), `antigravity` (no-op, le `.agents/rules/`
   nativamente, sem arquivo extra). Pode ser mais de um. Se omitir a flag, o
   script gera tudo (CLAUDE.md + .claude/ + AGENTS.md) por seguranca/retrocompat.

**Antes de montar o comando abaixo, valide `$nome`:** só prossiga se `$nome`
bater com `^[A-Za-z0-9][A-Za-z0-9._-]*$` (letras, numeros, `.`, `_`, `-`,
comecando por letra ou numero — sem barra, espaco, aspas, `$`, `` ` ``, `;`
ou qualquer outro caractere especial de shell). Se nao bater, **nao monte
nem execute o comando abaixo** — explique o motivo ao usuario e peca um
nome valido.

Essa validacao e a defesa real contra injecao de comando: `$nome` e
substituido como texto bruto (sem escaping) antes do comando ser executado,
entao `$(comando)` ou `` `comando` `` dentro de `$nome` executam mesmo
dentro de aspas duplas, independente do que `scripts/scaffold.sh` valide
depois (o script so ve o argumento ja processado pelo shell, tarde demais
pra bloquear o efeito colateral). Por isso este SKILL.md nao declara
`allowed-tools` pro Bash: a execucao sempre passa pela confirmacao normal
do Claude Code, que mostra o comando resolvido (com `$nome` ja substituido)
antes de rodar — segunda chance de flagrar um valor malicioso mesmo se a
validacao acima falhar. `scripts/scaffold.sh` faz a mesma checagem de novo,
mas so como guarda de path traversal / nomes invalidos pra quem roda o
script direto no terminal (ver README) — nao e defesa contra a injecao em
si.

**Essa segunda chance so existe se a sessao pedir confirmacao.** Com
`--dangerously-skip-permissions` ou modo auto-accept, o comando roda sem
mostrar nada pro usuario — a unica defesa que sobra e a validacao de texto
acima. Nao use essa skill em sessao assim.

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/scaffold.sh "$nome" --lang=<...> --agents=<...>
```

Depois de rodar, mostre a arvore gerada:

```bash
find "$nome" -not -path '*/node_modules/*' | sort
```

E explique ao usuario, em 3-4 linhas, a convencao:
- `.agents/` e a fonte de verdade cross-agent (rules, context, skills, templates, agents) — sempre gerada, independente de agentes escolhidos. Antigravity le nativamente.
- Entrypoints por agente sao condicionais: `CLAUDE.md`+`.claude/` so se `claude` estiver em `--agents`; `AGENTS.md` so se `grok`/`codex`/`cursor` estiver. `.claude/rules/*.md` sao symlinks pra `.agents/rules/` quando gerados — ativa path-scoping nativo do Claude Code sem duplicar conteudo.
- `docs/README.md` e o indice da pasta docs/ inteira (visao geral pra humanos); `docs/superpowers/specs/README.md` e so o indice mecanico de specs do fluxo SDD — escopos diferentes.
- `docs/superpowers/` segue o fluxo SDD descrito em `.agents/rules/spec-workflow.md`: `PRD.md` (intencao de produto, estavel), `ADR.md` (decisoes AD-NNN, append-only), `specs/` e `plans/` (por feature — toda spec nao-trivial inclui secao "Alternativas consideradas").
- `.editorconfig` tem uma secao `[*]` base valida pra qualquer linguagem, mais uma secao por linguagem escolhida em `--lang`. Toda regra de indentacao vem de fonte oficial (gofmt, PSR-12, rustfmt etc.) — nunca de suposicao. `.agents/rules/code-style.md` nao duplica indentacao, so aponta pro `.editorconfig`.
