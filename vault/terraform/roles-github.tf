# Роль = один кейс одного инструмента: какой репо, с каких ref, какие секреты.
# Имя: gh-<организация>-<репо>-<кейс>; в workflow — vault-action с role: <имя>
locals {
  github_roles = {
    "gh-finfix-go-server-deploy-dev" = {
      repo    = "finfix/go-server"
      refs    = ["refs/heads/release/*", "refs/heads/hotfix/*"]
      secrets = ["ci/k8s/coin/coin-server-dev", "ci/k8s/coin/helmfile-sops", "ci/github/finfix/read-submodules", "ci/notify/deploy"]
    }
    "gh-finfix-go-server-deploy-prod" = {
      repo    = "finfix/go-server"
      refs    = ["refs/tags/v*"]
      secrets = ["ci/k8s/coin/coin-server-prod", "ci/k8s/coin/helmfile-sops", "ci/github/finfix/read-submodules", "ci/notify/deploy"]
    }
    "gh-jedi-tasks-contracts-generate" = {
      repo    = "jedi-tasks/contracts"
      refs    = ["refs/tags/v*"]
      secrets = ["ci/github/jedi-tasks/push-grpc"]
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
