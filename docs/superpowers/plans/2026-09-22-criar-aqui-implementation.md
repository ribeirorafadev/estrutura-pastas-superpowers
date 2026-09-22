# Feature `--here` ("criar aqui") — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Nota pós-auditoria (2026-09-22):** a subpasta temporária usada em
> `--here` deixou de se chamar `$PROJECT_NAME` e passou a usar
> `mktemp -d` (nome aleatório `.scaffold-tmp.XXXXXX`) — fix pros achados
> 5 e 6 da auditoria independente. Os trechos de teste abaixo que
> assumem `$PROJECT_DIR` = `$DEST_PARENT/$PROJECT_NAME` refletem o
> desenho original; o comportamento final e os testes reais estão em
> `.github/workflows/test.yml` e documentados na spec correspondente.

**Goal:** Adicionar flag `--here` ao `scaffold.sh` — gera na subpasta temporária de sempre e, só após sucesso total, move o conteúdo pro destino, com checagem de colisão tudo-ou-nada.

**Architecture:** Zero mudança no caminho de geração existente. Bloco de guarda de destino no início (só ativo com `--here`) + bloco de move-com-checagem no final (só ativo com `--here`, só executa depois de `trap - ERR`).

**Tech Stack:** Bash (`set -euo pipefail`), testes via steps do GitHub Actions (`.github/workflows/test.yml`), mesmo padrão do resto do script (sem framework de teste externo).

**Spec:** `docs/superpowers/specs/2026-09-22-criar-aqui-design.md`

## Global Constraints

- Nunca alterar o comportamento default (sem `--here`) — toda mudança é aditiva e condicional a `[ "$HERE" = "1" ]`.
- `trap rm -rf "$PROJECT_DIR"` nunca pode mirar `$DEST_PARENT` — só a subpasta.
- Nenhuma escrita no destino final antes de todas as ~14 gerações internas terem sucesso.
- Colisão de qualquer item aborta o move inteiro — tudo ou nada, nunca merge parcial.
- Toda mensagem de erro/aviso em português, consistente com o resto do script.

---

### Task 1: Flag `--here` no parsing de argumentos + `--help`

**Files:**
- Modify: `scripts/scaffold.sh:4-35` (bloco de parsing) e o texto de `--help`
- Test: `.github/workflows/test.yml` (novo step)

**Interfaces:**
- Produces: variável `HERE` (`"0"` ou `"1"`), disponível pro resto do script.

- [ ] **Step 1: Escrever o teste (CI) que falha primeiro**

Adicionar em `.github/workflows/test.yml`, depois do último step existente (`Falha de ln -s limpa o projeto parcial e libera retry`):

```yaml
      - name: --help menciona --here
        run: bash scripts/scaffold.sh --help | grep -q -- '--here'
```

- [ ] **Step 2: Rodar localmente pra confirmar que falha**

Run: `bash scripts/scaffold.sh --help | grep -q -- '--here'`
Expected: sai com status 1 (grep não encontra `--here` no texto de uso ainda).

- [ ] **Step 3: Implementar**

Em `scripts/scaffold.sh`, no topo (perto de `LANGS=""` e `AGENTS=""`, linha 4-6):

```bash
LANGS=""
AGENTS=""
HERE=0
```

No `case "$arg" in` (dentro do loop de parsing, junto dos outros `--lang=*`/`--agents=*`, linha ~13-24), adicionar antes do `*)`:

```bash
    --here)
      HERE=1
      ;;
```

Atualizar as duas linhas de uso (`-h|--help` na linha 10, e a mensagem de erro de argumento faltando na linha 33) pra incluir `[--here]` no final:

```bash
      echo "Uso: scaffold.sh <nome-do-projeto> [diretorio-destino] [--lang=java,python,web,go,yaml,markdown,csharp,php,kotlin,rust,ruby] [--agents=claude,grok,codex,cursor,antigravity] [--here]"
```

(mesma string nas duas ocorrências — `--help` e o erro de uso.)

- [ ] **Step 4: Rodar o teste de novo, confirmar que passa**

Run: `bash scripts/scaffold.sh --help | grep -q -- '--here'`
Expected: sai com status 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/scaffold.sh .github/workflows/test.yml
git commit -m "feat(scaffold): adiciona flag --here (parsing + help)"
```

---

### Task 2: Guardas de destino (bloqueio de `$HOME`/`/`, escrita, existência)

**Files:**
- Modify: `scripts/scaffold.sh` — logo após `TEMPLATES_DIR` ser definido (linha ~50), antes do `if [ -e "$PROJECT_DIR" ]`
- Test: `.github/workflows/test.yml`

**Interfaces:**
- Consumes: `HERE` (Task 1), `DEST_PARENT` (já existe no script, linha 38).
- Produces: nada novo exportado — só efeito de `exit 1` em caso de destino inválido.

- [ ] **Step 1: Escrever os testes que falham primeiro**

```yaml
      - name: --here recusa destino que não existe
        run: |
          ! bash scripts/scaffold.sh t16-here-noexist /tmp/t16-nao-existe --agents=claude --here

      - name: --here recusa $HOME resolvido (blocklist)
        run: |
          mkdir -p /tmp/t17-fakehome
          ! HOME=/tmp/t17-fakehome bash scripts/scaffold.sh t17-proj /tmp/t17-fakehome --agents=claude --here
          test ! -f /tmp/t17-fakehome/CLAUDE.md
```

- [ ] **Step 2: Rodar localmente, confirmar que falham** (o segundo teste, por exemplo, hoje passaria pela geração inteira sem recusar nada — ainda não existe a guarda).

- [ ] **Step 3: Implementar**

Em `scripts/scaffold.sh`, logo depois de:

```bash
TEMPLATES_DIR="$SCRIPT_DIR/../templates"
```

adicionar:

```bash
if [ "$HERE" = "1" ]; then
  if [ ! -d "$DEST_PARENT" ]; then
    echo "Erro: --here exige que o diretorio destino '$DEST_PARENT' ja exista." >&2
    exit 1
  fi
  if [ ! -w "$DEST_PARENT" ]; then
    echo "Erro: sem permissao de escrita em '$DEST_PARENT' — --here abortado." >&2
    exit 1
  fi
  DEST_REAL="$(cd "$DEST_PARENT" && pwd -P)"
  if [ "$DEST_REAL" = "$HOME" ] || [ "$DEST_REAL" = "/" ]; then
    echo "Erro: --here recusado em '$DEST_REAL' — diretorio considerado perigoso demais pra escrita em lote (raiz do sistema ou do usuario)." >&2
    exit 1
  fi
fi
```

- [ ] **Step 4: Rodar os testes de novo, confirmar que passam**

- [ ] **Step 5: Commit**

```bash
git add scripts/scaffold.sh .github/workflows/test.yml
git commit -m "feat(scaffold): guardas de destino pra --here (existencia, escrita, blocklist)"
```

---

### Task 3: Move com checagem de colisão tudo-ou-nada

**Files:**
- Modify: `scripts/scaffold.sh` — bloco final (linhas ~189-191, `trap - ERR` + echo)
- Test: `.github/workflows/test.yml`

**Interfaces:**
- Consumes: `HERE`, `PROJECT_DIR`, `DEST_PARENT` (já existentes).
- Produces: comportamento final observável (arquivos em `$DEST_PARENT` em vez de `$PROJECT_DIR`).

- [ ] **Step 1: Escrever os testes que falham primeiro**

```yaml
      - name: --here move o conteudo pro destino, sem deixar subpasta
        run: |
          mkdir -p /tmp/t18-here-ok
          bash scripts/scaffold.sh t18-proj /tmp/t18-here-ok --agents=claude --here
          test -f /tmp/t18-here-ok/CLAUDE.md
          test -d /tmp/t18-here-ok/.agents
          test ! -e /tmp/t18-here-ok/t18-proj

      - name: --here aborta sem mover nada se houver colisao
        run: |
          mkdir -p /tmp/t19-collision
          echo "meu conteudo" > /tmp/t19-collision/.gitignore
          ! bash scripts/scaffold.sh t19-proj /tmp/t19-collision --agents=claude --here
          grep -q "meu conteudo" /tmp/t19-collision/.gitignore
          test ! -f /tmp/t19-collision/CLAUDE.md
          test -f /tmp/t19-collision/t19-proj/CLAUDE.md

      - name: --here com symlink .claude/rules continua valido apos o move
        run: |
          mkdir -p /tmp/t20-symlink
          bash scripts/scaffold.sh t20-proj /tmp/t20-symlink --agents=claude --here
          test -L /tmp/t20-symlink/.claude/rules/architecture.md
          readlink -f /tmp/t20-symlink/.claude/rules/architecture.md | grep -q '/tmp/t20-symlink/.agents/rules/architecture.md'
```

- [ ] **Step 2: Rodar localmente, confirmar que falham** (hoje `--here` já não quebra na guarda de destino, mas o script nunca move nada — os `test -f .../CLAUDE.md` no destino final vão falhar, e o `test ! -e .../t18-proj` vai falhar porque a subpasta continua existindo).

- [ ] **Step 3: Implementar**

Em `scripts/scaffold.sh`, substituir o final atual:

```bash
trap - ERR
echo "Estrutura criada em $PROJECT_DIR"
```

por:

```bash
trap - ERR

if [ "$HERE" = "1" ]; then
  COLLISIONS=""
  while IFS= read -r -d '' entry; do
    base="$(basename "$entry")"
    if [ -e "$DEST_PARENT/$base" ]; then
      COLLISIONS="$COLLISIONS $base"
    fi
  done < <(find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 -print0)

  if [ -n "$COLLISIONS" ]; then
    echo "Erro: --here abortado — ja existe em '$DEST_PARENT':$COLLISIONS" >&2
    echo "Nada foi movido. O conteudo gerado continua intacto em '$PROJECT_DIR' pra voce resolver manualmente." >&2
    exit 1
  fi

  find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 -exec mv -n -t "$DEST_PARENT" {} +
  if ! rmdir "$PROJECT_DIR" 2>/dev/null; then
    echo "Aviso: '$PROJECT_DIR' nao pode ser removida (nao esta vazia) — confira manualmente." >&2
  fi
  echo "Estrutura criada em $DEST_PARENT (--here)"
else
  echo "Estrutura criada em $PROJECT_DIR"
fi
```

- [ ] **Step 4: Rodar os testes de novo, confirmar que passam**

- [ ] **Step 5: Rodar a suite inteira do zero** (todos os steps do `test.yml`, do t1 ao t20, local) — confirmar que nada regrediu no caminho sem `--here`.

- [ ] **Step 6: Commit**

```bash
git add scripts/scaffold.sh .github/workflows/test.yml
git commit -m "feat(scaffold): move com checagem de colisao tudo-ou-nada pra --here"
```

---

### Task 4: SKILL.md — perguntar subpasta nova vs. aqui

**Files:**
- Modify: `SKILL.md`

- [ ] **Step 1: Adicionar a pergunta no fluxo de Q&A**, junto das perguntas de Stack/Agentes (depois do aviso de escopo já existente, antes da validação de `$nome`):

```markdown
3. **Onde criar** — se não estiver claro, pergunte: "criar numa subpasta
   nova chamada `<nome>` (padrão) ou direto aqui neste diretório?". Só
   ofereça "aqui" se o diretório atual estiver vazio (ou só com `.git`).
   Se o usuário escolher "aqui", adicione `--here` ao comando abaixo.
```

- [ ] **Step 2: Atualizar a linha do comando** (hoje `bash ${CLAUDE_SKILL_DIR}/scripts/scaffold.sh "$nome" --lang=<...> --agents=<...>`) pra:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/scaffold.sh "$nome" --lang=<...> --agents=<...> [--here]
```

- [ ] **Step 3: Commit**

```bash
git add SKILL.md
git commit -m "docs(skill): pergunta subpasta nova vs. --here no fluxo /novo-projeto"
```

---

### Task 5: README.md — documentar a flag

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Adicionar `--here` na linha de uso** (seção "Uso direto"):

```bash
bash scripts/scaffold.sh <nome-do-projeto> [diretorio-destino] \
  [--lang=java,python,web,go,yaml,markdown,csharp,php,kotlin,rust,ruby] \
  [--agents=claude,grok,codex,cursor,antigravity] \
  [--here]
```

- [ ] **Step 2: Adicionar um parágrafo explicando o comportamento** (gera na subpasta de sempre, move só no fim, aborta sem mover nada se colidir) com o mesmo exemplo do `.gitignore` colidindo usado na spec.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs(readme): documenta a flag --here"
```

## Self-Review

- **Cobertura da spec**: guardas 1-2 (blocklist, escrita) → Task 2; guardas 3-5 (colisão, mv -n, rmdir) → Task 3; guarda 6 (mesmo filesystem) → satisfeita por construção (`$PROJECT_DIR` sempre dentro de `$DEST_PARENT`, nenhuma task nova precisa); guarda 7 (trap inalterado) → nenhuma task toca no trap existente, só o que vem depois dele.
- **Sem placeholders**: todo step tem código completo, nenhum "adicione validação" vago.
- **Consistência de nomes**: `HERE` (variável), `--here` (flag), usados de forma idêntica em todas as tasks.
