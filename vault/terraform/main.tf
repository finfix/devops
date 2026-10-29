terraform {
  required_version = ">= 1.7"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }

  # State пока локальный (terraform.tfstate, в .gitignore) — запускать только с одной машины.
  # Позже — бэкенд pg в Postgres кластера coin
}

# Адрес и токен — из env VAULT_ADDR и ~/.vault-token (vault login -method=userpass)
provider "vault" {}
