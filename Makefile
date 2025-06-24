create-ansible-password-file:
	echo "Please enter the Ansible Vault password for the playbooks:"
	@read -s ansible_password; \
	echo $$ansible_password > .vault_password; \
	echo "Ansible Vault password file created."

users.init:
	ansible-playbook -i hosts.ini playbooks/init-users.yml --vault-password-file .vault_password

certs.init:
	ansible-playbook -i hosts.ini playbooks/init-certs.yml --vault-password-file .vault_password

setup.server:
	ansible-playbook -i hosts.ini playbooks/setup-server.yml --vault-password-file .vault_password

go-server.deploy:
	ansible-playbook -i hosts.ini playbooks/deploy-go-server.yml --vault-password-file .vault_password

go-server-dev.deploy:
	ansible-playbook -i hosts.ini playbooks/deploy-go-server-dev.yml --vault-password-file .vault_password

nginx.deploy:
	ansible-playbook -i hosts.ini playbooks/deploy-nginx.yml --vault-password-file .vault_password

secrets.decrypt:
	ansible-vault decrypt playbooks/secrets.yml --vault-password-file .vault_password

secrets.encrypt:
	ansible-vault encrypt playbooks/secrets.yml --vault-password-file .vault_password

docker.prune:
	ansible-playbook -i hosts.ini playbooks/docker-prune.yml  --vault-password-file .vault_password
