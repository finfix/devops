# Цели для CI: make_command в workflow сервисов вызывает их из корня devops (make deploy-coin-server).
# Те же задачи, что в Makefile, но с заданными параметрами — без интерактивных меню.

deploy-coin-server:
	@$(COMMON) do-k3s ACTION=apply ENV=prod RELEASE=coin-server

deploy-coin-server-dev:
	@$(COMMON) do-k3s ACTION=apply ENV=dev RELEASE=coin-server

deploy-tasks-server:
	@$(COMMON) do-k3s ACTION=apply ENV=prod RELEASE=tasks-server

deploy-tasks-server-dev:
	@$(COMMON) do-k3s ACTION=apply ENV=dev RELEASE=tasks-server

.PHONY: deploy-coin-server deploy-coin-server-dev deploy-tasks-server deploy-tasks-server-dev
