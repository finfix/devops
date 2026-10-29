# Задачи проекта. Реализация — в common/Makefile и common/scripts/make/.
# Без параметров каждая задача показывает меню; любой пункт можно задать переменной (см. make help).

COMMON := $(MAKE) --no-print-directory -f common/Makefile

# Список задач и параметров (задача по умолчанию)
help:
	@$(COMMON) $@

# Секреты ansible-хоста (vault)
edit-ansible-secrets:
	@$(COMMON) $@

# Ansible-плейбук: группа → плейбук → хост
run-ansible-playbook:
	@$(COMMON) $@

# Кластер k3s: действие → окружение → релиз
do-k3s:
	@$(COMMON) $@

.PHONY: help edit-ansible-secrets run-ansible-playbook do-k3s

# Цели для CI (make_command в workflow сервисов)
include ci.mk
