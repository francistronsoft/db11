# ISO offline Debian 11 / TronSoftOS

Nova linha de empacotamento 0.1.4, com TronSoftOS 0.1.135. O pacote 0.1.3
publicado anteriormente nao e modificado retroativamente.

## Conteudo

- Debian 11.11 DVD-1 oficial, SHA256 verificado antes da remasterizacao.
- Perfil servidor: console e SSH, sem GNOME, Xfce, KDE ou outra tarefa desktop.
- Pacotes .deb e indice APT local, incluindo dependencias do Firebird.
- Node 22, Docker/Compose e frontend ja compilado.
- FirebirdCS 2.5.9 e template.fdb obtidos do Bitrix e cobertos pelos checksums.
- Imagens prontas de backend, worker, PostgreSQL e Redis, carregadas localmente.
- Metadados Git para atualizacoes futuras pelo painel.

TronComanda, Retaguarda, Gerente, KDS e credenciais privadas NAO sao incluidos.
Cloudflare, GDrive e Central dependem de internet para operar e ficam para depois.

## Gerar

Em Linux amd64 com Docker e internet durante a geracao:

```bash
BUILD_OFFLINE=true bash scripts/build-kit.sh
bash scripts/build-iso.sh /caminho/debian-11.11.0-amd64-DVD-1.iso work/db11-kit-0.1.4-amd64
```

O gerador requer dpkg-scanpackages (dpkg-dev), xorriso e espaco suficiente para
imagens Docker, kit e ISO. Nao confundir o pacote normal com o pacote OFFLINE.
O workflow build-offline-core executa a geracao e publica artefatos temporarios.

## Instalar

Grave a ISO em pendrive (recomendado 16 GB), escolha o menu TronSoftOS offline
e instale o Debian normalmente. Disco, particionamento e senhas continuam
sob confirmacao do tecnico; a ISO nao predefine uma senha universal nem apaga
discos automaticamente. Os menus BIOS e UEFI originais sao preservados.

Depois do primeiro boot, entre como root e execute:

```bash
instalar
```

O comando instalar e copiado para /usr/local/sbin pelo instalador Debian e
executa o kit em /opt/db11-kit, independentemente do diretorio atual.
Nao inicia automaticamente e exige login como root. O assistente pede
identidade/rede. Nessa etapa nao deve haver npm install, docker build/pull ou
consulta a repositorio externo. APT usa somente o indice e os .deb locais;
imagens Docker sao importadas antes de subir o stack.

## Aceite necessario

Gerar arquivo e verificar checksum/entradas BIOS/UEFI nao comprova uma instalacao
funcional. Antes de liberar para hardware, testar em Debian 11 limpo, com saida
para internet bloqueada, verificando painel, autenticacao, banco template,
Firebird, backend/worker, PostgreSQL/Redis e reboot. Validar tambem o boot
do instalador da ISO em BIOS e UEFI. Manter esses resultados separados.
