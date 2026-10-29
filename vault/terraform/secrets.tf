# Секрет = единица доступа. На каждый — политика на чтение с именем пути через дефис:
# ci/jedi-tasks/github-pat → ci-jedi-tasks-github-pat
# Ключ внутри секрета называется как переменная в CI (PAT_TOKEN, KUBECONFIG, ...)
# Значения кладутся руками: vault kv put secret/<путь> KEY=...
locals {
  secrets = [
    "ci/coin/read-submodules",  # PAT_TOKEN — чтение приватных сабмодулей finfix
    "ci/coin/coin-server-dev",  # KUBECONFIG — ns dev
    "ci/coin/coin-server-prod", # KUBECONFIG — ns prod
    "ci/coin/helmfile-sops",    # SOPS_AGE — ключ k8s/secrets/*.yaml (убрать после переезда на ESO)
    "ci/coin/deploy-notify",    # TG_BOT_TOKEN, TG_CHAT_ID, TG_TOPIC_ID, GRAFANA_API_TOKEN, GRAFANA_URL

    "ci/jedi-tasks/github-pat", # PAT_TOKEN — пуш в go-server-grpc и swift-client-grpc
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
