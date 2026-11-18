# Dungeons and Habits

API inicial em Go, Fiber v3 e PostgreSQL/pgx, acompanhada de uma base de cliente iOS em SwiftUI. O back-end usa SQL direto, `pgxpool` para conexões concorrentes e transações nas operações que alteram XP, moedas, atributos ou inventário.

## Estrutura

```text
cmd/api/               inicialização do servidor
internal/domain/       modelos, enums e regras de domínio
internal/httpapi/      handlers e rotas REST
internal/guildprotocol/ tipos JSON compartilhados do chat e BBS P2P
internal/repository/   SQL e transações PostgreSQL
migrations/            schema inicial
Dockerfile             build multi-stage com runtime mínimo
compose.yaml           API + PostgreSQL para desenvolvimento local
src/                   cliente iOS em SwiftUI e serviços locais
  Plugins/             modelos, validação, regras e ciclo de vida dos plugins
```

## Protótipo web para PC

O protótipo em HTML5, CSS e JavaScript fica na raiz do projeto. Ele abre no navegador e já vem com uma aventura de demonstração; os dados e ações da demo ficam salvos no armazenamento local do navegador.

Para abrir a versão local, rode na pasta do projeto:

```bash
python3 -m http.server 5500
```

Depois acesse `http://localhost:5500`. Use **Configurações → Conexão** para informar a URL da API e o ID do usuário, ou **Configurações → Perfil → Criar usuário na API** para criar e conectar um usuário. O backend libera CORS somente para origens de loopback (`localhost` e IPs locais), para permitir esse uso durante o desenvolvimento.

O modo demonstração funciona sem banco de dados e sem servidor API. As quests, recompensas e o perfil inicial são fictícios e podem ser restaurados em **Configurações → Dados da demo**.

## Executar no Fedora com Docker

Com Docker Engine e o plugin Docker Compose instalados, na pasta do projeto:

```bash
docker compose up --build
```

A API fica em `http://localhost:8080`; o PostgreSQL fica na porta `5432`. O SQL de `migrations/001_init.sql` é aplicado automaticamente na primeira inicialização do volume.

Para executar a API diretamente no Fedora, instale Go 1.26 ou superior, inicie um PostgreSQL e defina `DATABASE_URL`. Depois:

```bash
psql "$DATABASE_URL" -f migrations/001_init.sql
go mod download
go run ./cmd/api
```

O arquivo `.env.example` mostra as variáveis aceitas. Go não carrega esse arquivo automaticamente; exporte as variáveis no terminal ou use o Compose.

## Rotas

| Método | Caminho | Uso |
|---|---|---|
| `GET` | `/healthz` | Verifica se o servidor HTTP está respondendo |
| `POST` | `/users` | Cria um usuário com role `user` e ficha inicial |
| `GET` | `/user/:id/sheet` | Ficha, atributos 5E e progressão dos subeixos |
| `GET` | `/quests?user_id=<uuid>` | Quests pendentes do usuário |
| `POST` | `/quests` | Cadastra uma quest |
| `POST` | `/quests/:id/complete` | Conclui a quest uma única vez e concede recompensas |
| `GET` | `/rewards?user_id=<uuid>` | Loja do usuário |
| `POST` | `/rewards` | Cadastra uma recompensa |
| `POST` | `/rewards/:id/buy` | Compra uma recompensa para o usuário informado |

### Exemplos

Criar usuário:

```bash
curl -X POST http://localhost:8080/users \
  -H 'Content-Type: application/json' \
  -d '{"username":"aventureiro_1"}'
```

Crie a quest usando o `id` retornado acima:

```bash
curl -X POST http://localhost:8080/quests \
  -H 'Content-Type: application/json' \
  -d '{
    "user_id":"UUID_DO_USUARIO",
    "title":"Estudar Go por 30 minutos",
    "description":"Ler e praticar um tópico novo.",
    "difficulty":"medium",
    "type":"monster_hunt",
    "axis_category":"financeiro",
    "subaxis":"estudos",
    "ability_key":"int",
    "is_daily":true
  }'
```

Listar quests e concluir uma:

```bash
curl 'http://localhost:8080/quests?user_id=UUID_DO_USUARIO'
curl -X POST http://localhost:8080/quests/UUID_DA_QUEST/complete
```

Cadastrar recompensa e comprar:

```bash
curl -X POST http://localhost:8080/rewards \
  -H 'Content-Type: application/json' \
  -d '{
    "user_id":"UUID_DO_USUARIO",
    "title":"Livro técnico",
    "description":"Livro para apoiar os estudos.",
    "cost":50,
    "type":"equipamento",
    "stat_key":"int",
    "stat_bonus":1
  }'

curl -X POST http://localhost:8080/rewards/UUID_DA_RECOMPENSA/buy \
  -H 'Content-Type: application/json' \
  -d '{"user_id":"UUID_DO_USUARIO"}'
```

## Regras iniciais

- Dificuldades `easy`, `medium`, `hard`, `epic` concedem respectivamente 10/25/50/100 XP e 5/12/25/50 moedas.
- Quests diárias voltam a aparecer como pendentes após a virada do dia UTC e podem conceder recompensa uma vez por dia UTC.
- O nível geral sobe ao atingir `100 × nível atual` XP. `xp_atual` guarda o progresso no nível e `xp_total`, o acumulado.
- A quest também concede XP ao subeixo escolhido. Cada 100 XP aumenta o nível daquele subeixo.
- Cada 100 XP da quest no atributo escolhido acrescenta 1 ponto ao atributo, limitado a 30. Isso é uma regra caseira inspirada na ficha 5E; ajuste no repositório conforme o balanceamento desejado.
- Um equipamento com `stat_bonus` aplica o bônus ao atributo ao ser comprado, limitado a 30. O inventário e o histórico de compras são registrados na mesma transação.
- `role` é sempre `user` no cadastro público. Para depuração local, um admin pode ser marcado diretamente no banco: `UPDATE users SET role = 'admin' WHERE username = 'aventureiro_1';`. Não há endpoints administrativos nesta base.
- A geração procedural de NPCs para questlines está marcada como TODO no código.

## Antes de publicar

Esta base **não implementa autenticação nem autorização por usuário**. Os IDs no corpo e nas rotas identificam registros, mas não provam quem está fazendo a chamada. Use-a localmente enquanto desenvolve; antes de disponibilizar a API na internet, adicione autenticação e verificação de propriedade nos handlers, além de TLS e gestão de segredos apropriada.

O endpoint `/healthz` é uma verificação de vida HTTP; a aplicação valida a conexão com o banco ao iniciar. O role `admin` está modelado para depuração futura, mas ainda não autoriza ações.

## Dependências

- Go 1.26+
- Fiber v3
- pgx v5 (`pgxpool`)
- PostgreSQL 17 no Compose



## App SwiftUI: integração com a API

A camada iOS fica nos arquivos Swift do diretório src. APIService usa URLSession e async/await; RemoteGameRepository implementa a porta GameRepository; GameManager mantém o estado consumido pelas Views. Os modelos usam CodingKeys explícitos para os nomes JSON do back-end, incluindo os campos em português.

A integração consome a ficha, quests pendentes, conclusão de quest, recompensas e compra. Para carregar a loja o app também usa GET /rewards?user_id=UUID, rota que já existe no servidor. A compra envia user_id no corpo, conforme o handler Go atual.

Para desenvolvimento local:

- Inicie o back-end com docker compose up --build.
- No Fedora, consulte o IPv4 da rede local com hostname -I.
- Na aba Configurações do app, informe http://IP_DO_FEDORA:8080 e o UUID de usuário criado pela rota POST /users.
- O iPhone e o Fedora precisam estar na mesma rede; permita a porta 8080 no firewall do Fedora se necessário.
- O Info.plist.example mostra as chaves para permissão de acesso à rede local e uma exceção ATS HTTP limitada à faixa 192.168.15.0/24. Troque essa faixa pela rede local real ou pelo IP fixo do Fedora e incorpore as chaves ao Info.plist do target iOS.

No iPhone, localhost aponta para o próprio iPhone, não para o Fedora. Em uma instalação iOS real, inclua NSLocalNetworkUsageDescription. Para desenvolvimento por HTTP em rede local, mantenha NSAllowsLocalNetworking e configure NSExceptionDomains para o IP ou a faixa CIDR do Fedora, como no Info.plist.example. Em um servidor publicado, use HTTPS.

O projeto não contém um arquivo de projeto Xcode. Inclua os arquivos Swift desta base em um target iOS 17 ou superior. DungeonsAndHabitsApp.swift é o ponto de entrada @main. As opções de API URL e UUID ficam salvas localmente no aparelho.

A autenticação ainda não existe no servidor. APIService recebe um TokenProvider opcional e adiciona Authorization: Bearer <token> automaticamente quando ele retorna um valor. Ao implementar JWT, injete um provedor que leia o token do Keychain; não armazene o token em UserDefaults.

### Módulo de plugins (`src/Plugins/`)

O módulo define uma base local para importar, validar, instalar, ativar, exportar e remover plugins declarativos. Os arquivos ficam organizados assim:

| Arquivo | Responsabilidade |
|---|---|
| `PluginModels.swift` | Modelos `Codable` do pacote, metadados, conteúdo, traduções e regras declarativas |
| `PluginManager.swift` | Ciclo de vida do plugin e prévia antes da confirmação da importação |
| `PluginValidation.swift` | Validação do esquema, conteúdo e checksum SHA-256 |
| `PluginRuleEngine.swift` | Interpretação nativa das condições e ações permitidas |
| `PluginStorage.swift` | Protocolos e implementações de persistência e registro de conteúdo |

#### Formato e importação

Um pacote `.dnhplugin` é um arquivo JSON UTF-8 não compactado, no formato de esquema v1. Ele inclui metadados (ID, versão, autor e escopos declarados), conteúdo (temas, presets de hábitos, quests, NPCs e recompensas), traduções e regras. A importação valida o arquivo e prepara uma prévia com o autor, a versão, os escopos e a contagem de itens. O conteúdo só é instalado depois que a interface chama `confirmImport()`; `cancelImport()` descarta a prévia.

O validador limita o pacote a 1 MiB, rejeita versões de esquema desconhecidas, IDs duplicados, conteúdo fora dos limites e regras com árvores excessivamente grandes ou profundas. O checksum SHA-256 detecta alterações acidentais no pacote, mas não autentica o autor nem substitui uma assinatura digital.

#### Regras e segurança

Plugins não carregam nem executam Swift, scripts arbitrários ou bytes WebAssembly. O motor nativo interpreta somente as condições permitidas (`skillLevelAtLeast`, `questCompleted`, `all` e `any`) e, nesta versão, a ação `unlockQuest`. Assim, as regras não concedem XP ou moedas diretamente. Um ponto de extensão para um motor Wasm aparece como comentário de trabalho futuro; ainda não há execução Wasm no app.

`PluginManager` persiste pacotes instalados em `Application Support/DungeonsAndHabits/Plugins` e oferece injeção de um `PluginContentRegistry`. A implementação atual desse registro é em memória (`InMemoryPluginContentRegistry`), então conectar o conteúdo dos plugins aos repositórios reais de temas, hábitos e quests ainda é uma etapa de integração. A tela de gerenciamento de plugins também precisa chamar esses métodos da interface.

## CI/CD do Go

Os workflows usam GitHub Actions. Depois que este projeto estiver em um repositório GitHub:

- `.github/workflows/go-ci.yml` roda em todo push, pull request e também pode ser iniciado manualmente. Verifica o `gofmt`, integridade das dependências, `go vet`, `go test`, compilação Go e build Docker.
- `.github/workflows/go-release.yml` publica uma imagem multi-arquitetura no GHCR quando recebe uma tag estável no formato `vMAJOR.MINOR.PATCH`, por exemplo `v0.1.0`.
- A imagem recebe tags sem o prefixo `v`: `0.1.0`, `0.1`, `0` e `latest`.

### Publicar uma versão

Crie e envie uma tag SemVer estável:

```bash
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

Depois que o workflow terminar, a imagem estará disponível em:

```text
ghcr.io/OWNER/REPOSITORY:0.1.0
```

Substitua `OWNER/REPOSITORY` pela conta e pelo nome do repositório GitHub. O workflow usa o `GITHUB_TOKEN` com permissão `packages: write`; não é necessário criar um token pessoal para publicar a imagem. Para permitir downloads anônimos, altere a visibilidade do pacote para pública nas configurações do GHCR.

### Executar as verificações localmente

```bash
go mod tidy
go vet ./...
go test ./...
go build -trimpath ./...
docker build --pull --tag dungeons-and-habits-api:local .
```

A publicação no GHCR entrega a imagem. O deploy automático em uma máquina específica ainda precisa de um destino e de credenciais configuradas para atualizar e reiniciar o serviço.
