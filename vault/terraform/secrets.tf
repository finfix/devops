# Секреты CI. Секрет = единица доступа. На каждый — политика на чтение с именем пути через дефис:
# jedi-tasks/ci/github-pat → jedi-tasks-ci-github-pat
# Схема путей — vault/README.md: <проект>/ci/<имя>; общая инфраструктура кластера — проект infra.
# Ключ внутри секрета называется как переменная в CI (PAT_TOKEN, KUBECONFIG, ...)
# Значения кладутся руками (vault kv put secret/<путь> KEY=...) или скриптом vault/migrate-from-sops.sh
locals {
  ci_secrets = [
    "coin/ci/github-pat",                  # PAT_TOKEN — чтение приватных сабмодулей finfix
    "coin/ci/coin-server-dev-kubeconfig",  # KUBECONFIG — ns dev
    "coin/ci/coin-server-prod-kubeconfig", # KUBECONFIG — ns prod

    "jedi-tasks/ci/github-pat",                   # PAT_TOKEN — пуш в go-server-grpc и swift-client-grpc, сборка и деплой сервера Tasks
    "jedi-tasks/ci/tasks-server-dev-kubeconfig",  # KUBECONFIG — ns dev кластера coin
    "jedi-tasks/ci/tasks-server-prod-kubeconfig", # KUBECONFIG — ns prod кластера coin

    "infra/ci/deploy-notify", # TG_BOT_TOKEN, TG_CHAT_ID, TG_TOPIC_ID, GRAFANA_API_TOKEN, GRAFANA_URL
    "infra/ci/wireguard",     # WG_CONFIG — конфиг пира github-ci (10.10.10.6) для доступа к kube-apiserver
  ]

  secrets = local.ci_secrets
}

resource "vault_policy" "secret_read" {
  for_each = toset(local.secrets)

  name   = replace(each.key, "/", "-")
  policy = <<-HCL
    path "${vault_mount.secret.path}/data/${each.key}" {
      capabilities = ["read"]
    }
  HCL
}
