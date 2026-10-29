# Vault

Сервер — релиз `vault` в `k8s/helmfile.yaml`, `https://vault.bonavii.com`.
Конфигурация (способы входа, политики, роли) — Terraform в `terraform/`.
Значения секретов в git не попадают — их кладут руками: `vault kv put secret/<путь> KEY=...`.

## Модель
| Сущность | Что это | Нейминг |
|---|---|---|
| Секрет | единица доступа: один кред, ключи внутри выдаются только вместе | `ci/<проект>/<имя>` |
| Политика | чтение одного секрета | путь через дефис |
| Роль | один кейс одного инструмента → набор секретов | `gh-<организация>-<репо>-<кейс>` |

Ключ внутри секрета называется как переменная в CI: `PAT_TOKEN`, `KUBECONFIG`, `SOPS_AGE`, `TG_BOT_TOKEN`, …

Эталон использования — `jedi-tasks/contracts` (`.github/workflows/build.yml`): в workflow явно указаны роль и пути:

```yaml
- uses: hashicorp/vault-action@v3
  with:
    url: https://vault.bonavii.com
    method: jwt
    role: gh-jedi-tasks-contracts-generate
    jwtGithubAudience: https://github.com/jedi-tasks
    secrets: |
      secret/data/ci/jedi-tasks/github-pat PAT_TOKEN
```

Джобе нужно `permissions: id-token: write`.

## Добавить роль
1. Секрет — строка в `terraform/secrets.tf`, значение — `vault kv put`.
2. Роль — блок в `terraform/roles-github.tf`.
3. `terraform plan` → проверить → `terraform apply`.

## Запуск
State пока локальный (`terraform/terraform.tfstate`, в `.gitignore`) — запускать только с одной машины,
иначе вторая не увидит созданное. Значений секретов в state нет, но в git его не кладём.
Позже переедет в Postgres кластера coin (бэкенд `pg`).

```bash
brew install hashicorp/tap/terraform hashicorp/tap/vault
export VAULT_ADDR=https://vault.bonavii.com
vault login -method=userpass username=<имя>

cd vault/terraform
terraform init
terraform plan
terraform apply
```

## Первый запуск (пустой Vault)
1. `terraform apply` под root-токеном из `vault operator init`: `VAULT_TOKEN=<root> terraform apply`.
2. Завести себе пользователя: `vault write auth/userpass/users/<имя> password=... token_policies=admin`.
3. Войти под ним (`vault login -method=userpass`) и отозвать root: `vault token revoke <root>`.
