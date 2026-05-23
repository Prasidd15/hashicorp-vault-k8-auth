path "secret/data/finance/accounts/*" {
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
