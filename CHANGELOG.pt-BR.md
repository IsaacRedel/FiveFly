# Histórico de mudanças

> English: [CHANGELOG.md](CHANGELOG.md)

Todas as mudanças relevantes do projeto ficam registradas aqui. O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e as versões seguem o [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [1.0.0] - Não lançada

Primeira versão pública do FiveFly, reescrita a partir do resource privado `mzm_CaliFY`.

### Adicionado

- Painel desktop aberto por comando ou tecla, compartilhando o estado com o app do celular. O lb-phone passou a ser opcional.
- Bridge de frameworks para Qbox, QBCore, ESX, vRP e standalone.
- Busca pela YouTube Data API oficial (convar `fivefly_youtube_key`), com scraping como alternativa.
- Migrações automáticas do banco, compatíveis com MySQL 8 e MariaDB.
- Inglês e português do Brasil: o `Config.Locale` troca a interface, as mensagens do console, a descrição do app no lb-phone, a descrição da tecla e a região da busca no YouTube. Comentários do config e documentação nos dois idiomas.
- O limite de playlists (`Config.Library.MaxPlaylists`) passou a ser aplicado.
- Testes Lua e da interface, workflows de CI e release e demo no navegador.

### Alterado

- Os jogadores são identificados por um identificador estável do framework, mapeado para um id interno (nunca o id do servidor).
- As chaves saíram do `config.lua` e viraram convars do servidor.
- O prop padrão da caixa de som é o `prop_boombox_01`, do jogo base.
- Tocar uma música a partir de uma lista mantém a ordem da lista.
- As músicas que avançam sozinhas passam a contar no histórico.

### Segurança

- Alcance, volume e posição do áudio espacial informados pelo client são limitados e validados no servidor, incluindo ids de entidade da caixa de som longe do jogador.
- URLs de stream enviadas pelo client só são aceitas quando batem com uma rádio configurada, então um client modificado não consegue fazer os jogadores próximos abrirem URLs arbitrárias.
- A validação de URLs de imagem rejeita hosts com credenciais ou caracteres incomuns.
- As sessões de reprodução são limpas quando o jogador desconecta.
