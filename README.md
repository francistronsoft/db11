# DB11 - kit Debian 11 para TronSoftOS

Kit reproduzivel para preparar os servidores legados do Provocateur com Debian 11.11 amd64, Firebird 2.5.9 e TronSoftOS.

O repositorio guarda scripts, versoes fixadas e documentacao. Pacotes `.deb`, Node.js, codigo compilado e arquivos finais ficam em `dist/` e devem ser publicados como artefatos de release, nao como arquivos Git.

## Decisoes de compatibilidade

- Debian Bullseye usa `archive.debian.org`, sem `bullseye-security`.
- Node.js `22.23.3` e instalado em `/opt` com checksum fixado.
- Docker CE, CLI, containerd, Buildx e Compose usam versoes Bullseye fixadas no manifesto.
- O TronSoftOS e empacotado em um commit exato e com o frontend previamente compilado.
- Tokens, bancos, configuracoes privadas e chaves SSH nunca entram no repositorio ou no bundle.

As versoes ficam em [`config/versions.env`](config/versions.env).

## Gerar o bundle

Execute em uma maquina Linux amd64 com Docker, Git e acesso a internet:

```bash
./scripts/build-kit.sh
```

Saidas:

```text
dist/db11-kit-0.1.0-amd64.tar.gz
dist/db11-kit-0.1.0-amd64.tar.gz.sha256
```

O workflow `build-installation-kit` executa o mesmo processo em Linux no GitHub Actions e publica o resultado como artefato `db11-kit-amd64`, com retencao de 14 dias.

Para empacotar outra revisao do TronSoftOS:

```bash
TRONSOFTOS_REF_OVERRIDE=<commit-ou-tag> ./scripts/build-kit.sh
```

## Instalar

No Debian 11 recem-instalado:

```bash
sha256sum --check db11-kit-0.1.0-amd64.tar.gz.sha256
tar -xzf db11-kit-0.1.0-amd64.tar.gz
cd db11-kit-0.1.0-amd64
sudo ./scripts/install-kit.sh --prepare-only
```

Depois de validar os pre-requisitos:

```bash
sudo ./scripts/install-kit.sh --install-tronsoftos
```

Leia [`docs/provocateur.md`](docs/provocateur.md) antes de formatar qualquer no.

## Validar o repositorio

```bash
./tests/static-check.sh
```
