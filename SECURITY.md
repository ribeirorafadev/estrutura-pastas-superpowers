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
CI (`.github/workflows/test.yml`). Riscos residuais já documentados e
aceitos por design (não são vulnerabilidades novas a reportar):

- Uso da skill com `--dangerously-skip-permissions` remove a confirmação
  de comando do Claude Code, que é a defesa real contra injeção via
  `$nome` — ver aviso em [README.md](README.md) e [SKILL.md](SKILL.md).
- **PATH poisoning**: `scaffold.sh` chama `sed`, `mktemp`, `find`, `ln`,
  `mv` sem caminho absoluto, confiando no `$PATH` do processo. Se um
  atacante já controla a ordem do `$PATH` do usuário (diretório gravável
  cedo no PATH, dotfile comprometido, instalador malicioso anterior), um
  binário homônimo malicioso pode substituir o conteúdo gerado. Exige
  comprometimento local prévio do ambiente — nesse cenário, qualquer outro
  comando que o usuário rode já está igualmente exposto, então resolver
  caminhos absolutos aqui não eleva a defesa real (e hardcode tipo
  `/usr/bin/sed` quebraria em sistemas onde essa localização difere, ex.:
  NixOS). Aceito como fora do modelo de ameaça desta skill (auditoria de
  2026-09-22, PoC real confirmou o vetor).
- **TOCTOU residual em `--here`** entre a checagem de colisão e o `mv`
  final (não o guard de `$HOME`, que usa caminho já resolvido de ponta a
  ponta desde a auditoria de 2026-09-22) — sem lock de filesystem entre
  duas execuções `--here` concorrentes no mesmo destino. Ver
  [`docs/superpowers/specs/2026-09-22-criar-aqui-design.md`](docs/superpowers/specs/2026-09-22-criar-aqui-design.md).
