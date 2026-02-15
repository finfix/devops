deploy-go-server:
	$(MAKE) -C ansible/servers/coin-server deploy-go-server

deploy-go-server-dev:
	$(MAKE) -C ansible/servers/coin-server deploy-go-server-dev

deploy-prod:
	$(MAKE) -C ansible upgrade-prod

deploy-dev:
	$(MAKE) -C k8s upgrade-dev

add-ansible-vault-password:
	echo $(VAULT_PASSWORD) > ansible/config/.vault_password
