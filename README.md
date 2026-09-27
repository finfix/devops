# Скрипты автоматизации настройки серверов

## Структура репозитория

- [Скрипты ansible для настройки инфраструктуры](ansible)
- [Конфигурация Ansible](ansible/config)
- [Общие роли Ansible (git submodule)](common/ansible/roles)
- [Проектные роли Ansible для повторного использования](ansible/roles)
- [Плейбуки Ansible для настройки серверов в разбивке по окружениям](ansible/playbooks)
- [Переменные окружения и секреты по хостам](ansible/host_vars)
- [Скрипты для вспомогательных задач](scripts)

## Подготовка
- [Конфигурация Ansible](ansible/config/README.md)

## Настройка серверов
- [Сервер Coin (k3s)](ansible/playbooks/k8s)
