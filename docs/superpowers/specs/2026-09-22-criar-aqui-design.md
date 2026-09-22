# Spec: opção `--here` ("criar aqui") no scaffold.sh

## Contexto

Hoje `scaffold.sh` sempre cria uma subpasta nova (`$DEST_PARENT/$PROJECT_NAME`)
e recusa rodar se ela já existir. Isso evita `~/Projetos/teste/teste/`
nunca acontecer — mas também gera exatamente essa pasta duplicada quando o
dev já está dentro de uma pasta vazia com o nome que ele quer usar.

Avaliamos permitir escrever direto no diretório atual (`cwd`) e uma
auditoria independente (subagente sem contexto prévio) concluiu que isso
quebraria a única invariante que protege hoje ~14 pontos de escrita do
script (garantia de que `$PROJECT_DIR` é sempre pasta nova). Recomendação
aceita: manter a geração 100% como está hoje, e só ao final — depois de
sucesso total — mover o conteúdo gerado pra `$DEST_PARENT` (padrão usado
por create-react-app/cookiecutter).

## Decisão

Implementar `--here` como flag opt-in (nunca default, nunca inferida).
Zero mudança no caminho de geração existente — a mudança inteira é um
bloco de guarda no início (recusa cedo se o destino for perigoso) e um
bloco de "mover com segurança" no final.

## Comportamento

1. Parsing de args ganha `--here` (flag booleana, sem valor).
2. Se `--here`: antes de gerar qualquer coisa, valida o destino
   (`$DEST_PARENT`):
   - Existe e é diretório — senão, erro e sai.
   - É gravável (`[ -w ]`) — senão, erro e sai.
   - Resolvido (`cd "$DEST_PARENT" && pwd -P`, segue symlink) não é `$HOME`
     nem `/` — bloqueio de destinos perigosos demais pra escrita em lote.
3. Geração roda **exatamente como hoje**, sem nenhuma alteração — grava
   tudo em `$PROJECT_DIR` = `$DEST_PARENT/$PROJECT_NAME`, com o mesmo
   `trap rm -rf "$PROJECT_DIR"` de sempre (nunca aponta pra `$DEST_PARENT`).
4. Só depois do `trap - ERR` (ou seja, só se todas as ~14 escritas tiveram
   sucesso), se `--here`:
   a. Lista os itens de topo de `$PROJECT_DIR`. Pra cada um, checa se já
      existe item de mesmo nome em `$DEST_PARENT`.
   b. **Qualquer colisão → aborta o move inteiro, tudo ou nada.** Nada é
      movido. Mensagem de erro lista o que colidiu. `$PROJECT_DIR` com o
      conteúdo gerado continua intacto pra resolução manual.
   c. Sem colisão: move cada item de `$PROJECT_DIR` pra `$DEST_PARENT`
      (`find ... -exec mv -n -t`, não glob — evita edge cases de nomes
      com espaço; `-n` é defesa em profundidade redundante com o passo a).
   d. `rmdir "$PROJECT_DIR"` (nunca `rm -rf`) — só remove se vazia. Se
      sobrou algo, avisa e não força remoção.

## Guardas de segurança

| # | Guarda | Por quê |
|---|---|---|
| 1 | Blocklist `$HOME`/`/` resolvido | Erro de operador (terminal aberto no lugar errado) não pode afetar a raiz do sistema/usuário |
| 2 | `[ -w "$DEST_PARENT" ]` cedo | Falha limpa antes de gerar qualquer coisa, não no meio |
| 3 | Colisão tudo-ou-nada, antes de mover | Nunca mistura conteúdo do dev com o gerado — ou tudo, ou nada |
| 4 | `mv -n` | Defesa em profundidade mesmo se o passo 3 tiver bug |
| 5 | `rmdir`, nunca `rm -rf`, na limpeza final | Falha visível é sempre preferível a apagar por engano |
| 6 | Subpasta temp sempre dentro de `$DEST_PARENT` | Garante mesmo filesystem — `mv` nunca vira copy+delete não-atômico |
| 7 | `trap rm -rf` inalterado (mira só a subpasta) | O único caminho destrutivo do script continua isolado do `cwd` do usuário |

## Riscos residuais aceitos (documentados, não eliminados)

- **TOCTOU** entre a checagem de colisão e o `mv` real — janela de
  milissegundos, não segundos/minutos (era a duração do wizard inteiro
  antes desse desenho). Não eliminável sem lock de filesystem; não
  implementado por ora (YAGNI — uso interativo de terminal, probabilidade
  baixíssima).
- **Concorrência** entre duas execuções simultâneas no mesmo destino — sem
  lock. Mesmo argumento de raridade acima.
- **Falha não capturável** (SIGKILL/OOM/queda de energia) durante o `mv` —
  nenhum software em userspace evita isso; janela de exposição é curta.

## Fora de escopo

- Escrita direta no `cwd` sem o padrão temp+move (rejeitado pela
  auditoria independente).
- Lock de concorrência via `flock` (YAGNI, ver riscos residuais acima).
- Merge automático de conteúdo colidente (rejeitado — fail-fast é mais
  seguro que decidir por conta própria o que fazer com dois arquivos de
  mesmo nome).

## Arquivos afetados

- `scripts/scaffold.sh` — flag `--here`, guardas de destino, bloco de move.
- `SKILL.md` — pergunta ao usuário se quer subpasta nova (padrão) ou aqui;
  mapeia pra `--here`.
- `README.md` — documenta a flag, exemplo de uso.
- `.github/workflows/test.yml` — testes cobrindo happy path, colisão,
  destino perigoso (`$HOME`), destino inexistente.

## Auditoria independente pós-implementação (2026-09-22)

Subagente sem contexto prévio (fresh) auditou a implementação com PoC real
pra cada tentativa de ataque, não só leitura de código. Achados e status:

| # | Achado | Severidade | Status |
|---|---|---|---|
| 1 | Symlink quebrado no destino furava a checagem `[ -e ]` (falso-negativo de colisão) — quebrava "tudo ou nada" | Médio | **Corrigido** — checagem agora usa `[ -e ] \|\| [ -L ]` |
| 2 | Blocklist de `$HOME` comparava string literal — furada por barra final e por `$HOME` visto através de symlink (padrão real em algumas distros Linux) | Médio | **Corrigido** — `$HOME` e o destino são canonicalizados via `cd -P && pwd` antes de comparar |
| 3 | `CDPATH` exportado fazia `cd && pwd` imprimir 2 linhas, nunca batendo com `$HOME` — desligava a blocklist inteira. Mesmo bug pré-existia em `SCRIPT_DIR` (fora do escopo de `--here`, mas mesma causa raiz) | Médio | **Corrigido** — `unset CDPATH` no topo do script |
| 4 | `mv -t` é extensão GNU — `--here` quebra no macOS (`mv: illegal option -- t`), que está na matrix do CI | Alto | **Corrigido** — trocado por `mv item dest/` (POSIX, um item por vez) |
| 5 | Corrida entre duas execuções `--here` simultâneas: mesmo nome de projeto causava trap de uma apagar o `PROJECT_DIR` da outra no meio da geração | Médio (já documentado como risco residual aceito, mas essa fatia específica não estava) | **Mitigado** — subpasta agora tem nome aleatório via `mktemp -d` (atômico), elimina a colisão por nome igual. TOCTOU no `mv` final continua risco residual aceito (ver seção acima) |
| 6 | Nome de projeto igual a um item que seria gerado (ex.: projeto chamado `docs`) fazia `--here` falhar sempre, achando a própria subpasta como colisão | Baixo (UX) | **Corrigido** — resolvido pelo mesmo fix do #5 (`mktemp`, nome não previsível) |
| 7 | Testes negativos com `! comando` no meio de um step (não na última linha) são isentos de `set -e` — viram no-op silencioso. Confirmado por teste de mutação (regex afrouxada, teste continuava "passando") | Médio (lacuna de teste, não do script) | **Corrigido** — todos os `! comando` de shell convertidos pra `comando && exit 1 \|\| true`; testes de regressão adicionados pros achados 1-3 e 6 |
| 8 | Mensagem de erro confusa quando destino é arquivo, não diretório | Baixo | **Corrigido** — mensagem distingue "não existe" de "existe mas não é diretório" |

Nenhum achado envolveu perda ou sobrescrita de dados do usuário — o
`trap` e o `mv -n` seguraram em todos os cenários testados. Os achados
eram sobre as garantias do design (tudo-ou-nada, blocklist, portabilidade)
não se sustentarem em condições adversariais específicas, não sobre dados
sendo destruídos silenciosamente.
