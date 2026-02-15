create-ansible-password-file:
	echo "Please enter the Ansible Vault password for the playbooks:"
	@read -s ansible_password; \
	echo $$ansible_password > .vault_password; \
	echo "Ansible Vault password file created."

edit-secrets:
	EDITOR="goland --wait" ansible-vault edit secrets.yml --vault-password-file config/.vault_password
