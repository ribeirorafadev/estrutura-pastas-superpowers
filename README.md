# novo-projeto

Scaffold de estrutura de pastas padrão pra projetos novos desenvolvidos com IA
como pair programming. Gera uma fonte de verdade cross-agent (`.agents/`), um
fluxo de Spec-Driven Development (PRD/ADR/specs/plans) e um `.editorconfig`
com cada regra de indentação vinda de fonte oficial — não de suposição.

## Quando usar

Feita pra **começar um projeto novo**, não pra injetar estrutura num projeto
já em andamento. Por padrão o script sempre cria uma subpasta nova com o
nome do projeto e recusa rodar se ela já existir (`Erro: '...' já existe`)
— nunca escreve por cima de arquivos existentes. Com `--here` (ver seção
abaixo), dá pra gerar direto no diretório atual sem a subpasta — mas o
mesmo princípio vale: se algo colidir, nada é movido, nunca sobrescreve.
Se você quer adotar `.agents/`/`docs/superpowers/` num projeto que já tem
código real, copie os templates manualmente em vez de rodar o scaffold
ali dentro.

## Estrutura do repositório

```
novo-projeto/
├── .github/
│   └── workflows/
│       └── test.yml          # CI: matrix ubuntu/macos/windows, 17 steps
├── scripts/
│   └── scaffold.sh           # gera a estrutura (único script executável)
├── templates/                # conteúdo copiado/adaptado pro projeto gerado
│   ├── AGENTS.md.tmpl
│   ├── CLAUDE.md.tmpl
│   ├── HANDOFF.md            # template — vira o HANDOFF.md do projeto gerado
│   ├── claude-settings.json
│   ├── docs-README.md
│   ├── docs/superpowers/     # PRD.md, ADR.md, specs/README.md
│   ├── editorconfig/         # um arquivo por linguagem suportada
│   └── rules/                # architecture.md, code-style.md, security.md, spec-workflow.md
├── CONTRIBUTING.md
├── LICENSE.md
├── README.md
├── SECURITY.md
└── SKILL.md                  # formato nativo de skill do Claude Code
```

`HANDOFF.md` na raiz (histórico de sessão desta skill, não do repositório
que você gera) é arquivo local, não versionado (`.gitignore`) — uso pessoal
entre sessões, não faz parte do que é publicado.

## Pré-requisitos

- `bash` + utilitários POSIX (`sed`, `ln -s`) — roda em qualquer terminal
  Unix-like (Linux, macOS, WSL, Git Bash). **No Windows nativo** (fora de
  WSL/Git Bash), `ln -s` exige Developer Mode habilitado ou o terminal
  rodando como administrador — sem isso, a criação dos symlinks em
  `.claude/rules/*.md` falha.
- Opcional: [Claude Code](https://claude.com/claude-code), pra usar como skill
  nativa (`/novo-projeto`).

## Instalação

```bash
git clone https://github.com/<seu-usuario>/novo-projeto.git ~/.agents/skills/novo-projeto
```

(Pode clonar em qualquer lugar — `~/.agents/skills/` é só a convenção usada
aqui pra manter `.agents/` como fonte única de verdade entre múltiplos projetos.)

### Ativar como skill nativa do Claude Code (opcional)

`~/.claude/` é local protegido — pra ativar o comando `/novo-projeto`, rode
uma vez:

```bash
ln -s ~/.agents/skills/novo-projeto ~/.claude/skills/novo-projeto
```

## Uso direto (qualquer terminal, sem Claude Code)

```bash
bash scripts/scaffold.sh <nome-do-projeto> [diretorio-destino] \
  [--lang=java,python,web,go,yaml,markdown,csharp,php,kotlin,rust,ruby] \
  [--agents=claude,grok,codex,cursor,antigravity] \
  [--here]
```

`<nome-do-projeto>` aceita apenas letras, números, `.`, `_` e `-`, começando
por letra ou número (sem barra, espaço ou outros caracteres especiais) —
o script rejeita qualquer outro valor antes de criar arquivos. Cada valor
de `--lang` passa pelo mesmo tipo de checagem (letras, números, `_`, `-`);
valor fora disso é ignorado com aviso, igual a uma linguagem desconhecida.
`--lang` e `--agents` são case-insensitive (`--lang=JAVA` e `--lang=java`
são equivalentes); passar a mesma flag duas vezes avisa em stderr e usa o
último valor. `--agents` com só valores desconhecidos cai pra gerar
`AGENTS.md` (fallback seguro, padrão aberto) em vez de não gerar nenhum
entrypoint.

`[diretorio-destino]` **não é validado** — é tratado como `mkdir`/`cp`
tratam um caminho: vai exatamente pra onde você apontar, incluindo `..`
pra subir níveis (uso legítimo normal). Se você integrar `scaffold.sh` num
script ou CI de terceiros, não passe esse argumento com valor vindo de
input externo não confiável (corpo de PR, webhook etc.) sem validar você
mesmo antes — a skill nunca passa esse argumento explicitamente no fluxo
`/novo-projeto` (fica sempre no padrão `.`, o diretório atual).

### `--here` — criar direto no diretório atual, sem subpasta

Por padrão, o script sempre cria uma subpasta nova com o nome do projeto.
Com `--here`, ele gera tudo normalmente numa subpasta temporária e, **só
se der tudo certo**, move o conteúdo pro diretório atual (ou pro
`[diretorio-destino]`, se informado) e apaga a subpasta temporária.

Antes de mover, ele confere item por item se algo com o mesmo nome já
existe no destino. **Se qualquer coisa colidir, nada é movido** — o erro
lista o que colidiu, e o conteúdo gerado continua intacto na subpasta
temporária pra você resolver manualmente:

```bash
$ cd meu-projeto-existente   # já tem um .editorconfig seu
$ bash scaffold.sh meu-projeto . --agents=claude --here
Erro: --here abortado — já existe em '.': .editorconfig
Nada foi movido. O conteúdo gerado continua intacto em './meu-projeto' pra você resolver manualmente.
```

`--here` também recusa rodar se o destino não existir, não for gravável,
ou resolver pra `$HOME`/raiz do sistema (proteção contra erro de operador
— terminal aberto no lugar errado). Ver
[`docs/superpowers/specs/2026-09-22-criar-aqui-design.md`](docs/superpowers/specs/2026-09-22-criar-aqui-design.md)
pra a análise de risco completa por trás desse desenho.

**Se você usa `/novo-projeto` via Claude Code, não rode a sessão com
`--dangerously-skip-permissions` (ou qualquer modo "aceita tudo
automaticamente").** O nome do projeto vira parte de um comando shell —
o Claude Code te mostra esse comando resolvido antes de rodar como última
trava de segurança; desligar a confirmação desliga essa trava também,
pra essa e qualquer outra skill.

Ambas as flags são opcionais e independentes:

- **`--lang`** — controla as seções do `.editorconfig` gerado. Sem a flag,
  sai só a seção `[*]` base.
- **`--agents`** — controla quais entrypoints de agente são gerados. Sem a
  flag, gera tudo (`CLAUDE.md` + `.claude/` + `AGENTS.md`). Com a flag, só o
  que foi pedido:
  - `claude` → `CLAUDE.md` + `.claude/` (rules symlinked, settings.json)
  - `grok` / `codex` / `cursor` → `AGENTS.md` na raiz (padrão aberto
    [agents.md](https://agents.md/) — o Grok Build também lê `AGENTS.md`
    diretamente, confirmado em [docs.x.ai](https://docs.x.ai/build/features/project-rules))
  - `antigravity` → nada extra, lê `.agents/rules/` nativamente

### Exemplo

Projeto Go (back-end) + React (front-end), usado com Grok e Antigravity via
terminal (sem Claude Code):

```bash
bash scripts/scaffold.sh meu-projeto --lang=go,web --agents=grok,antigravity
```

Gera `.agents/`, `docs/superpowers/`, `AGENTS.md`, `.editorconfig` (com
`indent_style = tab` pro Go e `indent_size = 2` pro React/web) — sem
`CLAUDE.md` nem `.claude/`, já que Claude Code não foi selecionado.

## Estrutura gerada

```
<projeto>/
├── .agents/                  # sempre gerado — fonte de verdade cross-agent
│   ├── rules/                 # architecture.md, code-style.md, security.md, spec-workflow.md
│   ├── context/                # README.md — glossário/regras de negócio (vazio de propósito)
│   ├── skills/                  # README.md — skills do projeto
│   ├── templates/
│   └── agents/                  # README.md — subagentes do projeto
├── docs/
│   ├── README.md
│   └── superpowers/
│       ├── PRD.md
│       ├── ADR.md
│       ├── specs/README.md
│       └── plans/
├── .claude/                  # só se --agents inclui "claude" (ou --agents omitido)
│   ├── rules/                 # symlinks pra .agents/rules/*.md
│   ├── skills/
│   ├── agents/
│   └── settings.json          # permissions.deny padrão pra .env*/*.pem/*.key
├── CLAUDE.md                 # idem
├── AGENTS.md                 # só se --agents inclui grok/codex/cursor (ou omitido)
├── HANDOFF.md
├── .editorconfig             # [*] base + uma seção por --lang pedido
└── .gitignore                # cobre .env*, *.pem, *.key, node_modules/, dist/
```

`.claude/` e `AGENTS.md` são mutuamente independentes — controlados só por
`--agents`. `antigravity` não gera arquivo extra (lê `.agents/rules/`
nativamente).

## O `.editorconfig`

Cada arquivo em `templates/editorconfig/` cita a fonte oficial usada (guia de
estilo, formatter oficial) — ver [`CONTRIBUTING.md`](CONTRIBUTING.md) pra
adicionar uma linguagem nova.

## Depois de gerar

1. Preencha `.agents/rules/architecture.md`, `code-style.md`, `security.md`
   com as decisões reais do projeto — saem vazios de propósito.
2. Promova subagentes/skills de `.agents/` pra `.claude/` (cópia ou symlink)
   se precisar de auto-invocação nativa desde o início.
3. Ajuste `.claude/settings.json` com permissions/hooks reais do projeto.

## Licença

MIT — ver [LICENSE.md](LICENSE.md).
