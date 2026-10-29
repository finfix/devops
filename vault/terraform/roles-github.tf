# Роль = один кейс одного инструмента: какой репо, с каких ref, какие секреты.
# Имя: gh-<организация>-<репо>-<кейс>; в workflow — vault-action с role: <имя>
locals {
  # Старые пути (ci/<проект>/<имя>) на время переезда: роли читают и старые, и новые.
  # Удаляются в PR «удаление SOPS» вместе с local.legacy_ci_secrets
  legacy_roles_secrets = {
    coin_dev   = ["ci/coin/github-pat", "ci/coin/coin-server-dev-kubeconfig", "ci/coin/helmfile-sops", "ci/coin/deploy-notify", "ci/coin/wireguard-ci"]
    coin_prod  = ["ci/coin/github-pat", "ci/coin/coin-server-prod-kubeconfig", "ci/coin/helmfile-sops", "ci/coin/deploy-notify", "ci/coin/wireguard-ci"]
    tasks_dev  = ["ci/jedi-tasks/github-pat", "ci/jedi-tasks/tasks-server-dev-kubeconfig", "ci/coin/helmfile-sops", "ci/coin/deploy-notify", "ci/coin/wireguard-ci"]
    tasks_prod = ["ci/jedi-tasks/github-pat", "ci/jedi-tasks/tasks-server-prod-kubeconfig", "ci/coin/helmfile-sops", "ci/coin/deploy-notify", "ci/coin/wireguard-ci"]
    contracts  = ["ci/jedi-tasks/github-pat"]
  }

  github_roles = {
    "gh-finfix-go-server-deploy-dev" = {
      repo    = "finfix/go-server"
      refs    = ["refs/heads/release/*", "refs/heads/hotfix/*"]
      secrets = concat(["coin/ci/github-pat", "coin/ci/coin-server-dev-kubeconfig", "infra/ci/deploy-notify", "infra/ci/wireguard"], local.legacy_roles_secrets.coin_dev)
    }
    "gh-finfix-go-server-deploy-prod" = {
      repo    = "finfix/go-server"
      refs    = ["refs/tags/v*"]
      secrets = concat(["coin/ci/github-pat", "coin/ci/coin-server-prod-kubeconfig", "infra/ci/deploy-notify", "infra/ci/wireguard"], local.legacy_roles_secrets.coin_prod)
    }
    # Сервер Tasks живёт в кластере coin: уведомления и WireGuard — общая инфраструктура (infra)
    "gh-jedi-tasks-server-deploy-dev" = {
      repo    = "jedi-tasks/server"
      refs    = ["refs/heads/release/*", "refs/heads/hotfix/*"]
      secrets = concat(["jedi-tasks/ci/github-pat", "jedi-tasks/ci/tasks-server-dev-kubeconfig", "infra/ci/deploy-notify", "infra/ci/wireguard"], local.legacy_roles_secrets.tasks_dev)
    }
    "gh-jedi-tasks-server-deploy-prod" = {
      repo    = "jedi-tasks/server"
      refs    = ["refs/tags/v*"]
      secrets = concat(["jedi-tasks/ci/github-pat", "jedi-tasks/ci/tasks-server-prod-kubeconfig", "infra/ci/deploy-notify", "infra/ci/wireguard"], local.legacy_roles_secrets.tasks_prod)
    }
    "gh-jedi-tasks-contracts-generate" = {
      repo    = "jedi-tasks/contracts"
      refs    = ["refs/tags/v*"]
      secrets = concat(["jedi-tasks/ci/github-pat"], local.legacy_roles_secrets.contracts)
    }
  }
}

resource "vault_jwt_auth_backend_role" "github" {
  for_each = local.github_roles

  backend         = vault_jwt_auth_backend.github.path
  role_name       = each.key
  role_type       = "jwt"
  user_claim      = "repository"
  bound_audiences = ["https://github.com/${split("/", each.value.repo)[0]}"]

  bound_claims_type = "glob"
  bound_claims = {
    repository = each.value.repo
    # Несколько значений claim — через запятую
    ref = join(",", each.value.refs)
  }

  token_policies = [for s in each.value.secrets : vault_policy.secret_read[s].name]
  token_ttl      = 600
  token_max_ttl  = 900
}
