# Checklist de teste no jogo

> English: [docs/testing-in-game.md](../testing-in-game.md)

Os testes automatizados (`lua tests/lua/run.lua` e `npm test` em `ui/`) cobrem a lógica pura, com as natives simuladas. Eles não comprovam que áudio, foco da NUI ou a integração com o celular funcionam no FiveM. Rode esta lista num servidor de teste antes de cada release, de preferência com dois jogadores.

## Inicialização

- [ ] `ensure oxmysql`, o framework, `lb-phone` (opcional) e `fivefly`, nessa ordem.
- [ ] O console mostra `framework: <nome>` e nenhum erro. Na primeira vez, `aplicando a migração 1 do banco` (ou a mensagem em inglês, conforme o `Config.Locale`).
- [ ] Reiniciar o `fivefly` com jogadores online não deixa uma camada cinza ou preta na tela.

## App do celular (lb-phone)

- [ ] O app FiveFly aparece e abre.
- [ ] A busca retorna resultados; tocar uma música inicia o áudio.
- [ ] Pausar, retomar, avançar no tempo, próxima, anterior, aleatório e repetir funcionam.
- [ ] Favoritas, playlists (criar, adicionar, remover, capa, visibilidade, excluir) e importação por código.
- [ ] Edição do perfil (avatar pela galeria e por URL), seguir outro jogador, playlists públicas no perfil dele.
- [ ] Largar o item de celular para a música iniciada pelo celular (`Config.Phone.StopWithoutPhoneItem`).

## Painel

- [ ] `/fivefly` (ou a tecla) abre o painel; Esc e o botão de fechar fecham e liberam o mouse.
- [ ] Ele controla a mesma reprodução do celular, e as mudanças em um aparecem no outro.
- [ ] Funciona num servidor **sem** lb-phone.
- [ ] A abertura é bloqueada com o personagem morto (`Config.Panel.CanOpen`), e o painel fecha quando o jogador morre.
- [ ] Nenhum fundo fora da janela do painel nas resoluções mais comuns (1366x768, 1920x1080, 2560x1440).

## Saídas e áudio espacial (dois jogadores)

- [ ] Privado: só o dono escuta.
- [ ] Caixa de som: o prop aparece na mão, o segundo jogador escuta com o volume caindo pela distância e para de escutar fora do alcance.
- [ ] Veículo: funciona no veículo atual; uma carreta de som engatada vira a origem do áudio; a música para quando o dono se afasta mais que `ownerMaxDistance`.
- [ ] Entrar numa sessão compartilhada toca a mesma música na mesma posição.

## Idioma

- [ ] Com `Config.Locale = "pt-BR"`, a interface, a descrição da tecla, a descrição do app no lb-phone e as mensagens do console ficam em português. Com `"en"`, tudo em inglês.

## Dados

- [ ] Ao reconectar, favoritas, playlists, histórico e perfil continuam lá.
- [ ] Frameworks com multipersonagem: trocar de personagem mostra outra biblioteca.
