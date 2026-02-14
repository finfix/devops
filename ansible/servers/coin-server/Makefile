export ANSIBLE_CONFIG = ../../config/ansible.cfg

init-users:
	ansible-playbook ../init-users.yml -e target=coin-server

setup-server:
	ansible-playbook setup-server.yml

docker-prune:
	ansible-playbook docker-prune.yml

deploy-go-server:
	ansible-playbook deploy-go-server.yml

deploy-go-server-dev:
	ansible-playbook deploy-go-server-dev.yml

upsert-certs:
	ansible-playbook upsert-certs.yml
