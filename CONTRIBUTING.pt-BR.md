# Como contribuir

> English: [CONTRIBUTING.md](CONTRIBUTING.md)

Obrigado por ajudar! Relatos de bugs, traduções e pull requests são bem-vindos.

## Relatando bugs

Abra uma issue informando o framework e a versão, a versão do lb-phone (se usar), os passos para reproduzir e a saída do console do servidor e do client. Use o modelo de bug report.

## Ambiente de desenvolvimento

- Lua 5.4 (`lua` e `luac` no PATH) para os testes Lua.
- Node.js 22+ para a interface.
- Um servidor FiveM de teste para tudo que envolve natives, áudio ou NUI.

```sh
cd ui && npm ci && npm run dev   # http://127.0.0.1:3002/preview.html com dados de exemplo
```

## Antes de abrir um pull request

```sh
lua tests/lua/run.lua                     # a partir da raiz do repositório
cd ui && npm run check                    # typecheck + testes + build
```

- Mantenha as mudanças focadas: uma funcionalidade ou correção por pull request.
- Valide no servidor tudo que mexe com estado importante, com o banco ou com outros jogadores: nunca confie em valores enviados pelo client.
- Novas ações da NUI ou do servidor precisam entrar em `docs/api-contract.md` e `docs/pt-BR/api-contract.md` (o teste de contrato confere a versão em inglês).
- Novos textos da interface vão em `ui/src/i18n/en.ts` e `ui/src/i18n/pt-BR.ts`; novos textos do Lua vão em `shared/locale.lua`, nos dois idiomas.
- Não faça commit de `ui/dist`: as releases geram esse build.
- Conte o que você testou no jogo, se testou. Os testes automatizados não cobrem áudio nem foco da NUI.

## Traduções

Interface: copie `ui/src/i18n/en.ts` para um novo arquivo tipado como `Messages`, traduza os valores e registre-o em `ui/src/i18n/index.ts`. Lua: adicione uma tabela com o mesmo código de idioma em `shared/locale.lua`.

## Estilo de código

- Lua: 4 espaços, tudo `local`, retornos antecipados e namespaces `FiveFly.*`. Anote os tipos compartilhados com comentários do LuaLS.
- TypeScript/React: componentes funcionais, estado em `ui/src/state` e nenhuma dependência nova de runtime sem discussão.
- Mantenha as páginas NUI transparentes fora dos próprios painéis (sem `color-scheme: dark` e sem `backdrop-filter` em wrappers de tela cheia).
