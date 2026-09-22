# Segurança — {{PROJECT_NAME}}

<!-- Preencha antes de codar — sem isso, todo input externo deveria ser
tratado como hostil por padrão (zero trust), mas o agente não sabe QUAIS
pontos são a fronteira de confiança real deste projeto até você dizer. -->

## Superfície de risco
- Autenticação/autorização: <!-- ex.: JWT via Auth0, sessão em cookie httpOnly -->
- Dados sensíveis manipulados: <!-- ex.: CPF, email, dados de pagamento — qualquer PII -->
- Dependências externas críticas: <!-- ex.: API de pagamento, serviço de auth terceirizado -->

## Política
- <!-- ex.: todo input de usuário validado na borda (DTO), nunca SQL concatenado (só ORM/prepared statement), segredos só via variável de ambiente/vault, nunca hardcoded -->

