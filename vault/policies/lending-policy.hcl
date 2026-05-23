path "secret/data/finance/lending/*" {
  capabilities = ["read", "list"]
}

path "secret/data/finance/shared/*" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
