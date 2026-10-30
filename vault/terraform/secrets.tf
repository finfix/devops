# Секрет = единица доступа. На каждый — политика на чтение с именем пути через дефис:
# ci/jedi-tasks/github-pat → ci-jedi-tasks-github-pat
# Ключ внутри секрета называется как переменная в CI (PAT_TOKEN, KUBECONFIG, ...)
# Значения кладутся руками: vault kv put secret/<путь> KEY=...
locals {
  secrets = [
    "coin/ci/github-pat",      # PAT_TOKEN — чтение приватных сабмодулей finfix
    "coin/ci/kubeconfig-dev",  # KUBECONFIG — ns dev
    "coin/ci/kubeconfig-prod", # KUBECONFIG — ns prod
    "coin/ci/helmfile-sops",   # SOPS_AGE — ключ k8s/secrets/*.yaml (убрать после переезда на ESO)
    "coin/ci/deploy-notify",   # TG_BOT_TOKEN, TG_CHAT_ID, TG_TOPIC_ID, GRAFANA_API_TOKEN, GRAFANA_URL
    "coin/ci/wireguard",       # WG_CONFIG — конфиг пира github-ci (10.10.10.6) для доступа к kube-apiserver

    "jedi-tasks/ci/github-pat",      # PAT_TOKEN — пуш в go-server-grpc и swift-client-grpc, сборка и деплой сервера Tasks
    "jedi-tasks/ci/kubeconfig-dev",  # KUBECONFIG — ns dev кластера coin
    "jedi-tasks/ci/kubeconfig-prod", # KUBECONFIG — ns prod кластера coin
  ]
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
