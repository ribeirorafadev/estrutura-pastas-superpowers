# Contribuindo com novo-projeto

Contribuições são bem-vindas, principalmente pra estender a cobertura de
linguagens do `.editorconfig` e de agentes de IA suportados.

## Adicionando suporte a uma linguagem nova

1. Crie `templates/editorconfig/<lang>.editorconfig` com a(s) seção(ões)
   `[*.ext]` correspondente(s).
2. **Toda regra de indentação precisa vir de fonte primária e oficial** —
   guia de estilo oficial da linguagem, formatter oficial (gofmt, rustfmt) ou
   padrão da organização mantenedora (ex.: PSR-12 pro PHP). PR com convenção
   sem fonte citada será devolvido pra ajuste.
3. Cite a fonte em comentário na seção — siga o padrão de `java.editorconfig`,
   `go.editorconfig` etc.
4. `<lang>` no nome do arquivo é o valor usado em `--lang=<lang>` — não
   precisa editar `scaffold.sh`, ele detecta o arquivo pelo nome.
5. Teste local antes do PR (o CI roda isso automaticamente):
   ```bash
   bash scripts/scaffold.sh teste-tmp /tmp --lang=<lang>
   cat /tmp/teste-tmp/.editorconfig
   ```

## Adicionando suporte a um agente de IA novo

1. Confirme, com fonte oficial (docs da ferramenta), qual arquivo/pasta esse
   agente lê nativamente como instrução de projeto.
2. Se ele já lê `AGENTS.md` (padrão [agents.md](https://agents.md/)) ou
   `CLAUDE.md`/`.claude/rules/`, provavelmente não precisa de nada novo — só
   adicionar o nome dele no `case` de `--agents` em `scripts/scaffold.sh`
   (grupo `grok|codex|cursor` ou equivalente).
3. Se ele exige um arquivo próprio, adicione um novo bloco condicional em
   `scaffold.sh` seguindo o padrão de `GEN_CLAUDE`/`GEN_AGENTS_MD`, com
   template em `templates/`.
4. Documente a fonte no `README.md` e no `SKILL.md`.

## Outras contribuições

Abra uma issue antes de PRs que mudem a estrutura de pastas gerada ou
`.agents/rules/*`, pra alinhar escopo. Correção de bug/typo pode ir direto.
