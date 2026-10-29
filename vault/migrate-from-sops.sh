#!/usr/bin/env bash
# Перенос секретов кластера coin из SOPS (k8s/secrets/secrets-<env>.yaml) в Vault по схеме vault/README.md
# и переезд секретов CI со старых путей ci/<проект>/<имя> на новые <проект>/ci/<имя>.
#
# Запускает человек, у которого есть age-ключ SOPS и admin-токен Vault:
#   export VAULT_ADDR=https://vault.bonavii.com && vault login -method=userpass username=<имя>
#   export SOPS_AGE_KEY_FILE=k8s/secrets/key.txt
#   vault/migrate-from-sops.sh --dry-run        # план: пути и ключи, ничего не расшифровывает и не читает из Vault
#   vault/migrate-from-sops.sh                  # перенос; существующие пути пропускаются
#   vault/migrate-from-sops.sh --force          # перезаписать существующие пути
#   vault/migrate-from-sops.sh --cluster-users  # дополнительно записать k8s/config/cluster-users/users.yaml (не секрет)
#
# Значения никуда не печатаются: SOPS расшифровывается в память, данные идут в `vault kv put` через stdin.
# На экран — только пути и имена ключей.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS_DIR="$ROOT/k8s/secrets"
MOUNT=secret

dry_run=false
force=false
cluster_users=false
for arg in "$@"; do
	case "$arg" in
		--dry-run) dry_run=true ;;
		--force) force=true ;;
		--cluster-users) cluster_users=true ;;
		-h | --help) sed -n '2,15p' "$0"; exit 0 ;;
		*) echo "Неизвестный аргумент: $arg" >&2; exit 1 ;;
	esac
done

for bin in python3 jq; do
	command -v "$bin" >/dev/null || { echo "Нужен $bin" >&2; exit 1; }
done
if ! $dry_run; then
	for bin in sops vault; do
		command -v "$bin" >/dev/null || { echo "Нужен $bin" >&2; exit 1; }
	done
	vault token lookup >/dev/null || { echo "Нет токена Vault: vault login -method=userpass" >&2; exit 1; }
fi

# Ключи SOPS-файла (имена хранятся открытым текстом) — для плана и проверки, без расшифровки
sops_has() { # файл, путь через точку
	python3 -I -c '
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
for k in sys.argv[2].split("."):
    if not isinstance(d, dict) or k not in d: sys.exit(1)
    d = d[k]' "$1" "$2"
}
sops_children() { # файл, путь через точку → имена дочерних ключей
	python3 -I -c '
import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
for k in sys.argv[2].split("."): d = d[k]
print("\n".join(d.keys()))' "$1" "$2"
}

vault_exists() { vault kv metadata get -mount="$MOUNT" "$1" >/dev/null 2>&1; }

# Записать путь: $1 — путь, stdin — JSON-объект {ключ: значение}. Печатает путь и ключи
put() {
	local path="$1" data keys
	data="$(cat)"
	keys="$(jq -r 'keys | join(", ")' <<<"$data")"
	if [ "$(jq 'length' <<<"$data")" = 0 ]; then
		echo "  пропуск   $path — нет ключей"
		return
	fi
	if vault_exists "$path" && ! $force; then
		echo "  есть      $path — пропуск (--force для перезаписи)"
		return
	fi
	jq -c . <<<"$data" | vault kv put -mount="$MOUNT" "$path" - >/dev/null
	echo "  записан   $path [$keys]"
}

# План одного пути из SOPS: $1 — файл, $2 — путь Vault, далее пары КЛЮЧ=путь.в.sops
plan() {
	local file="$1" path="$2"; shift 2
	local keys=() missing=() pair
	for pair in "$@"; do
		if sops_has "$file" "${pair#*=}"; then keys+=("${pair%%=*}"); else missing+=("${pair%%=*}←${pair#*=}"); fi
	done
	echo "  $path [${keys[*]:-}]${missing[*]:+  (нет в SOPS: ${missing[*]})}"
}

# Перенос одного пути из SOPS: аргументы как у plan; JSON SOPS — в переменной $decrypted
migrate() {
	local file="$1" path="$2"; shift 2
	local filter="{" pair sep=""
	for pair in "$@"; do
		filter+="$sep\"${pair%%=*}\": .${pair#*=}"
		sep=", "
	done
	filter+="} | with_entries(select(.value != null) | .value |= tostring)"
	jq "$filter" <<<"$decrypted" | put "$path"
}

for env in dev prod; do
	file="$SECRETS_DIR/secrets-$env.yaml"
	echo "== SOPS $env ($file)"

	specs=()
	specs+=("coin/coin-server/$env
		AUTH_TOKEN_SIGNING_KEY=coin_server.auth.key
		SHA_SALT=coin_server.auth.salt
		TG_BOT_TOKEN=coin_server.telegram_bot.token
		TG_CHAT_ID=coin_server.telegram_bot.chat_id
		API_KEY_CURRENCY_PROVIDER=coin_server.api_key_currency_provider
		NOTIFICATIONS_APNS_TEAM_ID=coin_server.apns.team_id
		NOTIFICATIONS_APNS_KEY_ID=coin_server.apns.key_id")
	specs+=("jedi-tasks/tasks-server/$env
		AUTH_TOKEN_SIGNING_KEY=tasks_server.auth.key
		SHA_SALT=tasks_server.auth.salt
		AUTH_INITIAL_USER_NAME=tasks_server.initial_user.name
		AUTH_INITIAL_USER_EMAIL=tasks_server.initial_user.email
		AUTH_INITIAL_USER_PASSWORD=tasks_server.initial_user.password")
	for user in $(sops_children "$file" pgsql.users); do
		specs+=("infra/postgres/$env/$user password=pgsql.users.$user.password")
	done
	specs+=("infra/registry/$env
		registry=image_credentials.registry
		username=image_credentials.username
		password=image_credentials.password")
	if [ "$env" = prod ]; then
		specs+=("infra/grafana/prod ADMIN_PASSWORD=grafana.adminPassword")
		specs+=("infra/alertmanager/prod
			TG_BOT_TOKEN=alertmanager.telegram_token
			TG_CHAT_ID=alertmanager.telegram_chat_id
			TG_TOPIC_ID=alertmanager.telegram_topic_id")
	fi

	if $dry_run; then
		for spec in "${specs[@]}"; do
			# shellcheck disable=SC2086
			plan "$file" $spec
		done
	else
		decrypted="$(sops -d --output-type json "$file")"
		for spec in "${specs[@]}"; do
			# shellcheck disable=SC2086
			migrate "$file" $spec
		done
		unset decrypted
	fi
	# coin_server.host нигде не используется — не переносится
done

echo "== CI: старые пути → новые"
moves=(
	"ci/coin/github-pat=coin/ci/github-pat"
	"ci/coin/coin-server-dev-kubeconfig=coin/ci/coin-server-dev-kubeconfig"
	"ci/coin/coin-server-prod-kubeconfig=coin/ci/coin-server-prod-kubeconfig"
	"ci/coin/deploy-notify=infra/ci/deploy-notify"
	"ci/coin/wireguard-ci=infra/ci/wireguard"
	"ci/jedi-tasks/github-pat=jedi-tasks/ci/github-pat"
	"ci/jedi-tasks/tasks-server-dev-kubeconfig=jedi-tasks/ci/tasks-server-dev-kubeconfig"
	"ci/jedi-tasks/tasks-server-prod-kubeconfig=jedi-tasks/ci/tasks-server-prod-kubeconfig"
)
for move in "${moves[@]}"; do
	from="${move%%=*}" to="${move#*=}"
	if $dry_run; then
		echo "  $from → $to (ключи как есть)"
		continue
	fi
	if ! vault_exists "$from"; then
		echo "  нет       $from — пропуск"
		continue
	fi
	vault kv get -format=json -mount="$MOUNT" "$from" | jq '.data.data' | put "$to"
done
echo "  ci/coin/helmfile-sops — не переносится, удалить после PR «удаление SOPS»:"
echo "    vault kv metadata delete -mount=$MOUNT ci/coin/helmfile-sops"

if $cluster_users; then
	out="$ROOT/k8s/config/cluster-users/users.yaml"
	echo "== cluster_users → $out (открытым текстом, не секрет)"
	if $dry_run; then
		echo "  записал бы список cluster_users из secrets-prod.yaml"
	else
		{
			echo "# Пользователи кластера (ServiceAccount + права). Перенесено из SOPS скриптом vault/migrate-from-sops.sh"
			sops -d --extract '["cluster_users"]' --output-type json "$SECRETS_DIR/secrets-prod.yaml" \
				| python3 -I -c 'import sys, json, yaml; yaml.safe_dump({"cluster_users": json.load(sys.stdin)}, sys.stdout, sort_keys=False, allow_unicode=True)'
		} >"$out"
		echo "  записан   $out — проверь и закоммить в ветку PR «удаление SOPS»"
	fi
fi
