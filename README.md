# DevOps environment for the project

## Подготовка

1. Установка ansible пароля
`make create-ansible-password-file`

## Последовательность установки

1. Устанавливаем пользователей
`make user.init`

2. Добавляем свой ключ
```
ssh-copy-id -i ~/.ssh/id_rsa_github.pub devops@coin-1
ssh-copy-id -i ~/.ssh/id_rsa.pub coin-1
```

3. Устанавливаем
`make certs.init`

4. Заходим на сервер и запускаем скрипт генерации сертификата
```
ssh coin-1 'sudo -S /tmp/generate-certs.sh'
```

4. Общая настройка сервера `make setup.init`
- Настройка необходимого файлового окружения проекта
- Настройка фаервола
- Установка докера
- Авторизация в Github и установка базового docker compose
- Установка и настройка Nginx
- Установка Portainer
- Установка Go сервера
- Установка Envoy
- Установка Vue клиента

## Дополнительные инструменты

- Очистка докера от мусора `make docker.prune`
- Деплой Go сервера `make go-server.deploy`
- Деплой Vue клиента `make vue-client.deploy`
- Деплой Nginx `make nginx.deploy`

## Работа с ansible vault
`make secrets.decrypt`
`make secrets.encrypt`
