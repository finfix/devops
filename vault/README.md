# Vault

Сервер — релиз `vault` в `k8s/helmfile.yaml`, `https://vault.bonavii.com` (внутри кластера — `http://vault.vault.svc:8200`).
Конфигурация (способы входа, политики, роли) — Terraform в `terraform/`.
Значения секретов в git не попадают — их кладут руками (`vault kv put`) или скриптом переноса.

Два потребителя:
- **CI** (GitHub Actions) — вход по OIDC-токену джобы (`auth/jwt`), `hashicorp/vault-action`.
- **Кластер coin** — Vault Secrets Operator (VSO) входит по токену сервис-аккаунта (`auth/kubernetes`)
  и создаёт из секретов Vault обычные `Secret`, которые поды подключают через `envFrom`.

## Схема путей
Одно kv-v2 хранилище `secret/`:

| Что | Путь | Ключи |
|---|---|---|
| Секрет CI | `<проект>/ci/<имя>` | как переменная в CI: `PAT_TOKEN`, `KUBECONFIG`, … |
| Сервис | `<проект>/<сервис>/<окружение>` | все секретные переменные окружения сервиса: `AUTH_TOKEN_SIGNING_KEY`, `SHA_SALT`, … |
| Пароль пользователя БД | `infra/postgres/<окружение>/<пользователь>` | `password` (имя пользователя = последний сегмент) |
| Registry (imagePullSecret) | `infra/registry/<окружение>` | `registry`, `username`, `password` |
| Grafana | `infra/grafana/prod` | `ADMIN_PASSWORD` |
| Alertmanager | `infra/alertmanager/prod` | `TG_BOT_TOKEN`, `TG_CHAT_ID`, `TG_TOPIC_ID` |
| CI, общее | `infra/ci/deploy-notify`, `infra/ci/wireguard` | `TG_*`/`GRAFANA_*`, `WG_CONFIG` |

Проекты: `coin` (coin-server), `jedi-tasks` (tasks-server), `infra` — общая инфраструктура кластера.
Имя-хвост добавляется, только когда части секрета нужны разным потребителям.
Пароль БД хранится один раз — в `infra/postgres/...`; сервис получает его через свою роль.

## Роли
| Потребитель | Роль | Где описана |
|---|---|---|
| CI | `gh-<организация>-<репо>-<кейс>` | `terraform/roles-github.tf`, пути — `terraform/secrets.tf` |
| Кластер | `k8s-<проект>-<сервис>-<окружение>` | `terraform/k8s.tf` |

Роль кластера привязана к одному сервис-аккаунту `<сервис>-vault` в namespace потребителя,
её политика (с тем же именем) читает только свои пути. Пример `k8s-coin-coin-server-dev`:
SA `dev/coin-server-vault`, пути `coin/coin-server/dev` и `infra/postgres/dev/coin`.
Инфраструктура: `k8s-infra-postgres-<env>` (`infra/postgres/<env>/*`, namespace `postgres-<env>`),
`k8s-infra-registry-<env>`, `k8s-infra-grafana-prod`, `k8s-infra-alertmanager-prod` (namespace `monitoring`).

## Как работает VSO
- Релиз `vault-secrets-operator` — оператор; `defaultVaultConnection` → `vault.vault.svc`.
- Релиз `vault-secrets` (`k8s/config/vault-secrets/values.yaml.gotmpl`, на окружение) — на каждого потребителя
  `ServiceAccount <имя>-vault` + `VaultAuth <имя>` (роль Vault) + `VaultStaticSecret` на каждый `Secret`.
- VSO перечитывает Vault раз в 60 с (`refreshAfter`); при изменении обновляет `Secret`
  и перезапускает Deployment из `rolloutRestartTargets`.
- Сервис получает два `Secret`, оба через `extraEnvFrom` общего чарта:
  - `<сервис>-vault` — ключи пути `<проект>/<сервис>/<окружение>` как есть;
  - `<сервис>-db` — `PGSQL_PASSWORD` из `infra/postgres/<окружение>/<пользователь>` (`transformation.templates`).
  `PGSQL_USER`/`PGSQL_DATABASE` — открытыми `envs`.
- Postgres: `postgres-auth` (ключ `postgres-password`, `auth.existingSecret` чарта bitnami) и
  `postgres-user-<пользователь>` для джобы `postgres-init`. Список пользователей — `pgsql_users` в `environments` helmfile.
- `registry-credentials` (`kubernetes.io/dockerconfigjson`), `grafana-admin`/`grafana-db`, `alertmanager-telegram`.
- Если Vault запечатан, VSO не обновляет секреты (уже созданные `Secret` остаются). Алерт `VaultSealed`.

## Добавить сервис
1. Секреты: `vault kv put secret/<проект>/<сервис>/<окружение> KEY=...`; пароль БД —
   `vault kv put secret/infra/postgres/<окружение>/<пользователь> password=...`, пользователя — в `pgsql_users`.
2. Роль: строка в `local.k8s_app_services` (`terraform/k8s.tf`) → `terraform apply`.
3. `k8s/config/vault-secrets/values.yaml.gotmpl` — потребитель в `$auths`, его секреты в `$secrets`.
4. Values сервиса — `extraEnvFrom` на `<сервис>-vault` и `<сервис>-db`; в helmfile — `needs` на `vault-secrets`.
5. `helmfile -e <env> -l name=vault-secrets apply`, затем деплой сервиса.

## Добавить секрет CI
1. Путь — строка в `local.ci_secrets` (`terraform/secrets.tf`), значение — `vault kv put`.
2. Роль — блок в `terraform/roles-github.tf`; в workflow — роль и пути:

```yaml
- uses: hashicorp/vault-action@v3
  with:
    url: https://vault.bonavii.com
    method: jwt
    role: gh-jedi-tasks-contracts-generate
    jwtGithubAudience: https://github.com/jedi-tasks
    secrets: |
      secret/data/jedi-tasks/ci/github-pat PAT_TOKEN
```

Джобе нужно `permissions: id-token: write`.

## Перенос из SOPS
Выполнен скриптом `vault/migrate-from-sops.sh` (удалён вместе с SOPS, есть в истории git).
`k8s/secrets/key.txt` больше не используется (остался в `.gitignore`, чтобы случайно не попасть в git).
После переезда всех вызывающих workflow удалить старый секрет: `vault kv metadata delete -mount=secret ci/coin/helmfile-sops`
(и остальные `ci/<проект>/*`).

## Unseal
Ручной: после рестарта пода Vault запечатан, пока не ввести ключи
(`kubectl -n vault exec -it vault-0 -- vault operator unseal`, по разу на ключ).
Алерт `VaultSealed` (`k8s/config/monitoring/values-alerts.yaml.gotmpl`): blackbox-проба
`/v1/sys/health` (модуль `vault_unsealed`, успех — 200/429; 503 — запечатан, 501 — не инициализирован) падает 2 минуты.

## Запуск Terraform
State пока локальный (`terraform/terraform.tfstate`, в `.gitignore`) — запускать только с одной машины.
Значений секретов в state нет, но в git его не кладём. Позже переедет в Postgres кластера coin (бэкенд `pg`).

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
