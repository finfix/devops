# Секрет = единица доступа. На каждый — политика на чтение с именем пути через дефис:
# ci/github/jedi-tasks/push-grpc → ci-github-jedi-tasks-push-grpc
# Значения кладутся руками: vault kv put secret/<путь> KEY=...
locals {
  secrets = [
    "ci/coin/read-submodules",  # TOKEN — чтение приватных сабмодулей finfix
    "ci/coin/coin-server-dev",  # KUBECONFIG — ns dev
    "ci/coin/coin-server-prod", # KUBECONFIG — ns prod
    "ci/coin/helmfile-sops",    # SOPS_AGE — ключ k8s/secrets/*.yaml (убрать после переезда на ESO)
    "ci/coin/deploy-notify",    # TG_BOT_TOKEN, TG_CHAT_ID, TG_TOPIC_ID, GRAFANA_TOKEN, GRAFANA_URL

    "ci/jedi-tasks/github-pat", # TOKEN — пуш в go-server-grpc и swift-client-grpc
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
