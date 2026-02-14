create-ansible-password-file:
	echo "Please enter the Ansible Vault password for the playbooks:"
	@read -s ansible_password; \
	echo $$ansible_password > .vault_password; \
	echo "Ansible Vault password file created."

deploy-go-server:
	$(MAKE) -C ansible/servers/coin-server deploy-go-server

deploy-go-server-dev:
	$(MAKE) -C ansible/servers/coin-server deploy-go-server-dev

add-ansible-vault-password:
	echo $(VAULT_PASSWORD) > ansible/config/.vault_password

edit-secrets:
	ansible-vault edit ansible/secrets.yml
