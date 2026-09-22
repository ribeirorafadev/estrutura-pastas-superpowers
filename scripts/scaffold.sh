#!/usr/bin/env bash
set -euo pipefail

LANGS=""
AGENTS=""
HERE=0
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      echo "Uso: scaffold.sh <nome-do-projeto> [diretorio-destino] [--lang=java,python,web,go,yaml,markdown,csharp,php,kotlin,rust,ruby] [--agents=claude,grok,codex,cursor,antigravity] [--here]"
      exit 0
      ;;
    --lang=*)
      if [ -n "$LANGS" ]; then
        echo "Aviso: '--lang' passado mais de uma vez — sobrescrevendo '$LANGS' com '${arg#--lang=}'." >&2
      fi
      LANGS="${arg#--lang=}"
      ;;
    --agents=*)
      if [ -n "$AGENTS" ]; then
        echo "Aviso: '--agents' passado mais de uma vez — sobrescrevendo '$AGENTS' com '${arg#--agents=}'." >&2
      fi
      AGENTS="${arg#--agents=}"
      ;;
    --here)
      HERE=1
      ;;
    *)
      POSITIONAL+=("$arg")
      ;;
  esac
done
set -- "${POSITIONAL[@]+"${POSITIONAL[@]}"}"

if [ $# -lt 1 ]; then
  echo "Uso: scaffold.sh <nome-do-projeto> [diretorio-destino] [--lang=java,python,web,...] [--agents=claude,grok,codex,cursor,antigravity] [--here]" >&2
  exit 1
fi

PROJECT_NAME="$1"
DEST_PARENT="${2:-.}"

# Allowlist estrito: bloqueia path traversal (sem "/"), nomes "." /".."
# (exige começar com letra/numero) e quebra do delimitador do sed usado
# abaixo (que também não tolera "/"). Ver CONTRIBUTING.md / SKILL.md.
if [[ ! "$PROJECT_NAME" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "Erro: nome de projeto inválido '$PROJECT_NAME'. Use apenas letras, números, '.', '_' e '-', começando por letra ou número (sem barra, espaço ou outros caracteres especiais)." >&2
  exit 1
fi

PROJECT_DIR="$DEST_PARENT/$PROJECT_NAME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"

# --here: valida o destino ANTES de gerar qualquer coisa — falha cedo e
# limpo em vez de gerar tudo pra só descobrir no final que o destino era
# perigoso ou inválido.
if [ "$HERE" = "1" ]; then
  if [ ! -d "$DEST_PARENT" ]; then
    echo "Erro: --here exige que o diretório destino '$DEST_PARENT' já exista." >&2
    exit 1
  fi
  if [ ! -w "$DEST_PARENT" ]; then
    echo "Erro: sem permissão de escrita em '$DEST_PARENT' — --here abortado." >&2
    exit 1
  fi
  DEST_REAL="$(cd "$DEST_PARENT" && pwd -P)"
  if [ "$DEST_REAL" = "$HOME" ] || [ "$DEST_REAL" = "/" ]; then
    echo "Erro: --here recusado em '$DEST_REAL' — diretório considerado perigoso demais pra escrita em lote (raiz do sistema ou do usuário)." >&2
    exit 1
  fi
fi

if [ -e "$PROJECT_DIR" ]; then
  echo "Erro: '$PROJECT_DIR' já existe." >&2
  exit 1
fi

# Resolve quais entrypoints de agente gerar. Sem --agents: gera tudo (retrocompat
# com uso antigo, sem regressao). Com --agents: so o que foi pedido.
#   claude              -> CLAUDE.md + .claude/ (rules symlinked, settings.json, skills/agents vazios)
#   grok|codex|cursor   -> AGENTS.md na raiz (padrao aberto agents.md, ja confirmado
#                          suportado pelo Grok Build via docs.x.ai/build/features/project-rules)
#   antigravity         -> no-op: le .agents/rules/ nativamente, sem arquivo extra
GEN_CLAUDE=1
GEN_AGENTS_MD=1
if [ -n "$AGENTS" ]; then
  GEN_CLAUDE=0
  GEN_AGENTS_MD=0
  ANY_AGENT_RECOGNIZED=0
  IFS=',' read -ra AGENT_LIST <<< "$AGENTS"
  for agent in "${AGENT_LIST[@]}"; do
    agent="$(printf '%s' "$agent" | tr '[:upper:]' '[:lower:]')"
    case "$agent" in
      claude) GEN_CLAUDE=1; ANY_AGENT_RECOGNIZED=1 ;;
      grok|codex|cursor) GEN_AGENTS_MD=1; ANY_AGENT_RECOGNIZED=1 ;;
      antigravity) ANY_AGENT_RECOGNIZED=1 ;;
      *) echo "Aviso: agente desconhecido '$agent' — ignorado (conhecidos: claude, grok, codex, cursor, antigravity)." >&2 ;;
    esac
  done
  # Nenhum valor de --agents foi reconhecido: em vez de nao gerar nenhum
  # entrypoint (usuario fica sem guia nenhum pro agente real dele), cai
  # pra AGENTS.md como fallback seguro — e o padrao aberto agents.md, que
  # cada vez mais ferramentas fora desta lista tambem leem nativamente.
  if [ "$ANY_AGENT_RECOGNIZED" = "0" ]; then
    GEN_AGENTS_MD=1
    echo "Aviso: nenhum valor reconhecido em --agents='$AGENTS' — gerando AGENTS.md como fallback (padrao aberto agents.md, lido por varias ferramentas alem das listadas em --agents)." >&2
  fi
fi

echo "Criando estrutura em $PROJECT_DIR ..."

# Se algo falhar daqui pra frente (ex.: ln -s sem permissao no Windows sem
# Developer Mode), remove o que ja foi criado em vez de deixar o projeto
# pela metade travando um retry com "ja existe".
trap 'rm -rf "$PROJECT_DIR"' ERR

mkdir -p "$PROJECT_DIR"/.agents/rules
mkdir -p "$PROJECT_DIR"/.agents/context
mkdir -p "$PROJECT_DIR"/.agents/skills
mkdir -p "$PROJECT_DIR"/.agents/templates
mkdir -p "$PROJECT_DIR"/.agents/agents
mkdir -p "$PROJECT_DIR"/docs/superpowers/specs
mkdir -p "$PROJECT_DIR"/docs/superpowers/plans
mkdir -p "$PROJECT_DIR"/docs

# .agents/rules — copia templates com nome do projeto (sempre gerado: fonte
# de verdade cross-agent, independente de qual agente foi escolhido)
for f in architecture code-style security spec-workflow; do
  sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$TEMPLATES_DIR/rules/$f.md" > "$PROJECT_DIR/.agents/rules/$f.md"
done

cat > "$PROJECT_DIR/.agents/context/README.md" <<'EOF'
Contexto de domínio do projeto (glossário, regras de negócio, schema de dados). Um arquivo por assunto. Referencie em CLAUDE.md via @.agents/context/<arquivo>.md.
EOF

cat > "$PROJECT_DIR/.agents/skills/README.md" <<'EOF'
Skills específicas deste projeto. Cada skill: pasta com SKILL.md (formato oficial Claude Code — funciona também como doc pra outros agentes).

Pra funcionar nativamente no Claude Code (auto-invocação por description), copie ou symlink a pasta pra .claude/skills/<nome>/ e confira com /context se foi carregada. Sem isso, a skill só entra em contexto se referenciada manualmente no CLAUDE.md.
EOF

cat > "$PROJECT_DIR/.agents/agents/README.md" <<'EOF'
Subagentes deste projeto. Cada um: pasta própria com agent.md (frontmatter name+description compatível com o formato nativo do Claude Code).

Pra funcionar nativamente (Task tool, tools/model/permissionMode restritos, contexto isolado), copie ou symlink agent.md pra .claude/agents/<nome>.md e confira com /context. Sem isso é só texto colado via @import.
EOF

sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$TEMPLATES_DIR/docs/superpowers/PRD.md" > "$PROJECT_DIR/docs/superpowers/PRD.md"
sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$TEMPLATES_DIR/docs/superpowers/ADR.md" > "$PROJECT_DIR/docs/superpowers/ADR.md"
sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$TEMPLATES_DIR/docs-README.md" > "$PROJECT_DIR/docs/README.md"
sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$TEMPLATES_DIR/docs/superpowers/specs/README.md" > "$PROJECT_DIR/docs/superpowers/specs/README.md"

sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$TEMPLATES_DIR/HANDOFF.md" > "$PROJECT_DIR/HANDOFF.md"

# CLAUDE.md + .claude/ — so se "claude" estiver em --agents (ou --agents omitido)
if [ "$GEN_CLAUDE" = "1" ]; then
  mkdir -p "$PROJECT_DIR"/.claude/rules
  mkdir -p "$PROJECT_DIR"/.claude/skills
  mkdir -p "$PROJECT_DIR"/.claude/agents

  # .claude/rules — symlink relativo por arquivo (path-scoping nativo, sem duplicar conteudo)
  for f in "$PROJECT_DIR"/.agents/rules/*.md; do
    base="$(basename "$f")"
    ln -s "../../.agents/rules/$base" "$PROJECT_DIR/.claude/rules/$base"
  done

  sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$TEMPLATES_DIR/CLAUDE.md.tmpl" > "$PROJECT_DIR/CLAUDE.md"
  cp "$TEMPLATES_DIR/claude-settings.json" "$PROJECT_DIR/.claude/settings.json"
fi

# AGENTS.md — so se grok/codex/cursor estiver em --agents (ou --agents omitido)
if [ "$GEN_AGENTS_MD" = "1" ]; then
  sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$TEMPLATES_DIR/AGENTS.md.tmpl" > "$PROJECT_DIR/AGENTS.md"
fi

# .editorconfig — base universal + secao por linguagem (--lang=java,python,web,...)
EDITORCONFIG_DIR="$TEMPLATES_DIR/editorconfig"
cat "$EDITORCONFIG_DIR/base.editorconfig" > "$PROJECT_DIR/.editorconfig"
if [ -n "$LANGS" ]; then
  IFS=',' read -ra LANG_LIST <<< "$LANGS"
  for lang in "${LANG_LIST[@]}"; do
    lang="$(printf '%s' "$lang" | tr '[:upper:]' '[:lower:]')"
    if [[ ! "$lang" =~ ^[a-z0-9_-]+$ ]]; then
      echo "Aviso: valor invalido em --lang: '$lang' — ignorado (sem barra, espaco ou caracteres especiais)." >&2
      continue
    fi
    lang_file="$EDITORCONFIG_DIR/$lang.editorconfig"
    if [ -f "$lang_file" ]; then
      cat "$lang_file" >> "$PROJECT_DIR/.editorconfig"
    else
      echo "Aviso: sem template de .editorconfig pra linguagem '$lang' — seção não adicionada (linguagens disponíveis: java, python, web, go, yaml, markdown, csharp, php, kotlin, rust, ruby)." >&2
    fi
  done
else
  echo "Nenhum --lang informado — .editorconfig criado só com a seção [*] base." >&2
fi

cat > "$PROJECT_DIR/.gitignore" <<'EOF'
node_modules/
dist/
.claude/settings.local.json
CLAUDE.local.md
.env
.env.local
.env.*.local
*.pem
*.key
EOF

trap - ERR

# --here: so move depois de TODA a geracao ter tido sucesso (trap ja
# desarmado acima). Colisao em qualquer item aborta o move inteiro —
# tudo ou nada, nunca mistura conteudo do dev com o gerado.
if [ "$HERE" = "1" ]; then
  COLLISIONS=""
  while IFS= read -r -d '' entry; do
    base="$(basename "$entry")"
    if [ -e "$DEST_PARENT/$base" ]; then
      COLLISIONS="$COLLISIONS $base"
    fi
  done < <(find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 -print0)

  if [ -n "$COLLISIONS" ]; then
    echo "Erro: --here abortado — já existe em '$DEST_PARENT':$COLLISIONS" >&2
    echo "Nada foi movido. O conteúdo gerado continua intacto em '$PROJECT_DIR' pra você resolver manualmente." >&2
    exit 1
  fi

  find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 -exec mv -n -t "$DEST_PARENT" {} +
  if ! rmdir "$PROJECT_DIR" 2>/dev/null; then
    echo "Aviso: '$PROJECT_DIR' não pôde ser removida (não está vazia) — confira manualmente." >&2
  fi
  echo "Estrutura criada em $DEST_PARENT (--here)"
else
  echo "Estrutura criada em $PROJECT_DIR"
fi
