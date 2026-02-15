export SOPS_AGE_KEY_FILE=config/key.txt
TAG ?= latest
DESCRIPTION ?= Manual deploy

dependency-build:
	helm dependency build

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

uninstall-prod:
	helm uninstall prod -n prod

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

uninstall-dev:
	helm uninstall dev -n dev

edit-secrets-prod:
	EDITOR="goland --wait" sops --config config/.sops.yaml -i values/secrets-prod.yaml

edit-secrets-dev:
	EDITOR="goland --wait" sops --config config/.sops.yaml -i values/secrets-dev.yaml

deploy-prod:
	helmfile -e prod apply
