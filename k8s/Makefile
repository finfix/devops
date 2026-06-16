export SOPS_AGE_KEY_FILE=config/key.txt
TAG ?= latest
DESCRIPTION ?= Manual deploy

dependency-build:
	helm dependency build

# Секреты
edit-secrets-prod:
	EDITOR="goland --wait" sops --config config/.sops.yaml -i config/secrets-prod.yaml

edit-secrets-dev:
	EDITOR="goland --wait" sops --config config/.sops.yaml -i config/secrets-dev.yaml

# Тестирование
template-prod:
	helmfile -e prod template

template-dev:
	helmfile -e dev template

write-values-prod:
	helmfile -e prod write-values

write-values-dev:
	helmfile -e dev write-values

# Деплой
deploy-prod:
	helmfile -e prod apply

deploy-dev:
	helmfile -e dev apply

upgrade-prod:
	helm secrets upgrade \
	--install \
	--create-namespace prod \
	-n prod \
	-f values/values-prod.yaml \
	-f values/secrets-prod.yaml \
	--set coin_server.image.tag=${TAG} \
	--description "${DESCRIPTION}" \
	./


upgrade-dev:
	helm secrets upgrade \
	--install \
	--create-namespace dev \
	-n dev \
	-f values/values-dev.yaml \
	-f values/secrets-dev.yaml \
	--set coin_server.image.tag=${TAG} \
	--description "${DESCRIPTION}" \
	./

uninstall-prod:
	helm uninstall ingress-nginx -n ingress-nginx-prod

uninstall-dev:
	helm uninstall dev -n dev
