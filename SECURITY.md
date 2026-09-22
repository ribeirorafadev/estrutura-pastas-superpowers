# Política de segurança

`scripts/scaffold.sh` monta comandos shell a partir de input do usuário
(nome do projeto, `--lang`) — é a superfície de ataque mais sensível desta
skill. Duas rodadas de auditoria já cobriram injeção de comando, path
traversal e leitura arbitrária de arquivo (ver histórico de commits e
`SKILL.md`), mas reporte qualquer vetor novo que encontrar.

## Como reportar

**Não abra uma issue pública** para vulnerabilidades — isso expõe o exploit
antes de existir correção. Em vez disso:

- Use [GitHub Security Advisories](../../security/advisories/new) deste
  repositório (aba **Security** → **Report a vulnerability**), ou
- Envie um e-mail para rafael10.ribeiro21@gmail.com com assunto
  `[novo-projeto] vulnerabilidade`.

Inclua: passos de reprodução, impacto esperado, e se possível uma PoC
mínima. Responsabilidade: só uso pra correção, sem exploração adicional.

## O que esperar

- Confirmação de recebimento em até 7 dias.
- Correção ou plano de mitigação comunicado antes de qualquer disclosure
  pública.
- Crédito ao reporter (a menos que peça anonimato).

## Escopo

Cobre `scripts/scaffold.sh`, os templates gerados
(`templates/claude-settings.json`, `.editorconfig` gerado) e o workflow de
CI (`.github/workflows/test.yml`). Risco residual já documentado e aceito
por design: uso da skill com `--dangerously-skip-permissions` remove a
confirmação de comando do Claude Code, que é a defesa real contra injeção
via `$nome` — ver aviso em [README.md](README.md) e [SKILL.md](SKILL.md).
Isso não é uma vulnerabilidade nova a reportar, é limitação estrutural
conhecida.
