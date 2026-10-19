# DB11 - kit Debian 11 para TronSoftOS

Kit reproduzivel para preparar os servidores legados do Provocateur com Debian 11.11 amd64, Firebird 2.5.9 e TronSoftOS.

O repositorio guarda scripts, versoes fixadas e documentacao. Pacotes `.deb`, Node.js, codigo compilado e arquivos finais ficam em `dist/` e devem ser publicados como artefatos de release, nao como arquivos Git.

## Decisoes de compatibilidade

- Debian Bullseye usa snapshots imutaveis do repositorio principal e do ultimo `bullseye-security`.
- Node.js `22.23.3` e instalado em `/opt` com checksum fixado.
- Docker CE, CLI, containerd, Buildx e Compose usam versoes Bullseye fixadas no manifesto.
- O TronSoftOS e empacotado em um commit exato e com o frontend previamente compilado.
- Kit `0.1.5`: inclui TronSoftOS `0.1.136`, protecao contra reserva presa em upload invalido, metadados Git e geracao opcional de pacote/ISO offline.
- Tokens, bancos, configuracoes privadas e chaves SSH nunca entram no repositorio ou no bundle.

As versoes ficam em [`config/versions.env`](config/versions.env).

## Gerar o bundle

Execute em uma maquina Linux amd64 com Docker, Git e acesso a internet:

```bash
./scripts/build-kit.sh
```

Saidas:

```text
dist/db11-kit-0.1.5-amd64.tar.gz
dist/db11-kit-0.1.5-amd64.tar.gz.sha256
```

O workflow `build-installation-kit` executa o mesmo processo em Linux no GitHub Actions e publica o resultado como artefato `db11-kit-amd64`, com retencao de 14 dias.

Para empacotar outra revisao do TronSoftOS:

```bash
TRONSOFTOS_REF_OVERRIDE=<commit-ou-tag> ./scripts/build-kit.sh
```

## Instalar

No Debian 11 recem-instalado:

```bash
sha256sum --check db11-kit-0.1.5-amd64.tar.gz.sha256
tar -xzf db11-kit-0.1.5-amd64.tar.gz
cd db11-kit-0.1.5-amd64
sudo ./scripts/install-kit.sh --prepare-only
```

Depois de validar os pre-requisitos:

```bash
sudo ./scripts/install-kit.sh --install-tronsoftos
```

Leia [`docs/provocateur.md`](docs/provocateur.md) antes de formatar qualquer no.

## ISO sem internet

O pacote normal continua usando internet. Para a ISO com sistema operacional,
repositorio APT local, Firebird/template e imagens prontas do TronFire, leia
[`docs/iso-offline.md`](docs/iso-offline.md). Somente o bundle gerado com
`BUILD_OFFLINE=true` pode ser instalado com `--offline`.

## Atualizacoes pelo painel

O kit 0.1.3 inclui `TRONSOFTOS_GIT.tar.gz`, coberto pelos checksums do bundle.
Ao terminar a instalacao, restaura somente `/opt/tronsoftos/.git`, com a
propriedade do usuario de servico `tronsoftos`, branch `main` e remoto `origin`.
O commit e validado antes e depois da restauracao. Nao executa checkout/reset
sobre arquivos instalados e nao sobrescreve `.env`, estado ou configuracoes.

Se ja existir um repositorio, ele e validado e preservado. Se o commit, a
branch ou o remoto forem diferentes dos incluidos no kit, a instalacao da
aplicacao e recusada antes de copiar o codigo; use o atualizador do painel.
A criacao do vinculo funciona offline; buscar futuras versoes exige internet.

Pacotes 0.1.2 ja baixados continuam antigos. Para novas instalacoes use o
artefato gerado pelo build 0.1.3. A correcao nao modifica servidores existentes
automaticamente nem exige reinstalacao do Debian.

## Validar o repositorio

```bash
./tests/static-check.sh
```
