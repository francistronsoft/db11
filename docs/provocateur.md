# Instalacao no Provocateur

Este kit prepara Debian 11 amd64 para o TronSoftOS usando snapshots imutaveis do ultimo conjunto Bullseye disponivel.

## Ordem obrigatoria

1. Formate apenas um no por vez.
2. Mantenha o no ativo atual e o banco validado enquanto prepara o outro.
3. Copie o kit para o Debian 11 recem-instalado.
4. Verifique o arquivo externo `SHA256SUMS` antes de extrair o kit.
5. Execute primeiro somente os pre-requisitos:

   ```bash
   sudo ./scripts/install-kit.sh --prepare-only
   ```

6. Confira `node --version`, `docker --version`, `docker compose version` e `systemctl status ssh`.
7. Instale o TronSoftOS:

   ```bash
   sudo ./scripts/install-kit.sh --install-tronsoftos
   ```

8. Configure e valide o no como `recovery` ou `standby`. Nao entregue o VIP antes de restaurar e validar o banco.
9. Restaure o banco a partir do no que estiver ativo. O banco antigo do servidor formatado nao deve voltar para producao.
10. So formate o segundo no depois que o primeiro estiver acessivel por SSH, registrado na Central e com banco validado.

## Cloudflare

O token do Provocateur nao pertence a este repositorio nem ao bundle. Ele foi salvo separadamente no computador de manutencao:

```text
C:\Users\Francis\Documents\Provocateur-reinstall\cloudflare-tunnel-provocateur.json
```

O token deve ser aplicado apenas durante a instalacao. Nunca copie esse JSON para o Git ou para o arquivo distribuido do kit.

## Repositorios

O kit usa snapshots fixos dos repositorios principal e de seguranca:

```text
deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/20260831T000000Z/ bullseye main contrib non-free
deb [check-valid-until=no] https://snapshot.debian.org/archive/debian-security/20260901T000000Z/ bullseye-security main
```

Essas URLs nao recebem novas atualizacoes. Elas preservam um conjunto coerente para reinstalacao, mas nao reabrem o suporte de seguranca encerrado do Debian 11.
