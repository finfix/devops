create-ansible-password-file:
	echo "Please enter the Ansible Vault password for the playbooks:"
	@read -s ansible_password; \
	echo $$ansible_password > ansible/config/.vault_password; \
	echo "Ansible Vault password file created."

add-ansible-vault-password:
	echo $(VAULT_PASSWORD) > ansible/config/.vault_password


deploy-go-server:
	$(MAKE) -C ansible/servers/coin-server deploy-go-server

deploy-go-server-dev:
	$(MAKE) -C ansible/servers/coin-server deploy-go-server-dev

deploy-prod:
	$(MAKE) -C ansible upgrade-prod

deploy-dev:
	$(MAKE) -C k8s upgrade-dev
