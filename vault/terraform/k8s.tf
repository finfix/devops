# Вход кластера coin (Vault Secrets Operator, VSO) по токену сервис-аккаунта.
# Vault работает в этом же кластере и проверяет токены через TokenReview своим сервис-аккаунтом
# (ClusterRoleBinding system:auth-delegator создаёт чарт vault)
resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  backend         = vault_auth_backend.kubernetes.path
  kubernetes_host = "https://kubernetes.default.svc"
}

# Роль = один потребитель в кластере: k8s-<проект>-<сервис>-<окружение>.
# Сервис-аккаунт <сервис>-vault в namespace потребителя (создаёт релиз vault-secrets),
# политика с тем же именем читает только перечисленные пути.
# Схема путей — vault/README.md. Добавить сервис: запись здесь + ресурсы в k8s/config/vault-secrets
locals {
  k8s_environments = ["dev", "prod"]

  # Сервисы проектов: свой путь <проект>/<сервис>/<окружение> + пароль своего пользователя БД
  k8s_app_services = {
    "coin-server"  = { project = "coin", db_user = "coin" }
    "tasks-server" = { project = "jedi-tasks", db_user = "tasks" }
  }

  k8s_apps = merge([
    for service, s in local.k8s_app_services : {
      for env in local.k8s_environments : "k8s-${s.project}-${service}-${env}" => {
        namespace       = env
        service_account = "${service}-vault"
        paths = [
          "${s.project}/${service}/${env}",
          "infra/postgres/${env}/${s.db_user}",
        ]
      }
    }
  ]...)

  # Общая инфраструктура кластера (проект infra)
  k8s_infra = merge(
    {
      for env in local.k8s_environments : "k8s-infra-postgres-${env}" => {
        # postgres (пароль суперпользователя) и postgres-init (пароли всех пользователей БД)
        namespace       = "postgres-${env}"
        service_account = "postgres-vault"
        paths           = ["infra/postgres/${env}/*"]
      }
    },
    {
      for env in local.k8s_environments : "k8s-infra-registry-${env}" => {
        # imagePullSecret registry-credentials в namespace окружения
        namespace       = env
        service_account = "registry-credentials-vault"
        paths           = ["infra/registry/${env}"]
      }
    },
    {
      "k8s-infra-grafana-prod" = {
        namespace       = "monitoring"
        service_account = "grafana-vault"
        paths           = ["infra/grafana/prod", "infra/postgres/prod/grafana"]
      }
      "k8s-infra-alertmanager-prod" = {
        namespace       = "monitoring"
        service_account = "alertmanager-vault"
        paths           = ["infra/alertmanager/prod"]
      }
    },
  )

  k8s_roles = merge(local.k8s_apps, local.k8s_infra)
}

resource "vault_policy" "k8s" {
  for_each = local.k8s_roles

  name = each.key
  policy = join("\n", [
    for p in each.value.paths : <<-HCL
      path "${vault_mount.secret.path}/data/${p}" {
        capabilities = ["read"]
      }
    HCL
  ])
}

resource "vault_kubernetes_auth_backend_role" "k8s" {
  for_each = local.k8s_roles

  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = each.key
  bound_service_account_names      = [each.value.service_account]
  bound_service_account_namespaces = [each.value.namespace]
  # Аудитория токена, который VSO выпускает для сервис-аккаунта (VaultAuth.spec.kubernetes.audiences)
  audience       = "vault"
  token_policies = [vault_policy.k8s[each.key].name]
  token_ttl      = 600
  token_max_ttl  = 1200
}
