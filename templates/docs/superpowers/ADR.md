# {{PROJECT_NAME}} — Log de Decisões Arquiteturais (ADR)

Log append-only. Nunca editar ou apagar entrada antiga — para substituir, crie nova `AD-NNN` e marque a antiga como `superseded by AD-NNN`.

Critério pra virar entrada aqui (os três, simultâneos): difícil de reverter, surpreendente sem contexto, produto de trade-off real. Ver `.agents/rules/spec-workflow.md`.

## Template de entrada

```markdown
## AD-NNN: <título curto da decisão>

**Data:** YYYY-MM-DD
**Origem:** `specs/[data]-[slug]-design.md` (ou "N/A" se a decisão não veio de uma spec)
**Contexto:** <1-3 frases: qual problema ou trade-off forçou a decisão>
**Decisão:** <o que foi decidido>
**Alternativas consideradas:** <opcional — só quando a rejeição de uma alternativa não é óbvia>
```

`**Origem:**` é o que fecha o ciclo spec → decisão: aponta pro arquivo de spec que gerou a decisão, não só descreve a decisão isolada.

---
