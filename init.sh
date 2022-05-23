#!/bin/bash

echo "Vault auto-init start"
echo "Sleeping for 10 seconds for other containers to start."
sleep 10
export VAULT_ADDR="http://127.0.0.1:8200"

check_status() {
  echo "Checking Vaults status"
  INIT=$(curl -s http://127.0.0.1:8200/v1/sys/health | jq -r '.initialized')
  SEAL=$(curl -s http://127.0.0.1:8200/v1/sys/health | jq -r '.sealed')
  echo "Vault status; initialized=$INIT, sealed=$SEAL"

}
check_mount() {
  USERPASS=$(curl -s --header "X-Vault-Token: $SECRET_ROOT_TOKEN" http://127.0.0.1:8200/v1/sys/auth | jq -r '.data."userpass/".uuid')
  echo "Auth method userpass uuid: $USERPASS"
}

init_vault() {
  echo "Vault is not initialized. Attempting to init now." 
  INIT_OUTPUT=$(vault operator init -key-shares=1 -key-threshold=1 -format json)
  ROOT_TOKEN=$(echo $INIT_OUTPUT | jq -r '.root_token')
  UNSEAL_KEY=$(echo $INIT_OUTPUT | jq -r '.unseal_keys_b64[0]')

  # Store the root token and unseal key in a Kubernetes secret or other Vault pods can access it.
  kubectl create secret generic vault-token \
    --from-literal=root_token=$ROOT_TOKEN \
    --from-literal=unseal_key=$UNSEAL_KEY \
    --dry-run=client \
    -o yaml | \
    kubectl apply -f -
}

unseal_vault() {
  echo "Vault sealed. Attempting to unseal now." 
  vault operator unseal $SECRET_UNSEAL_KEY
  sleep 5
  export VAULT_TOKEN=$SECRET_ROOT_TOKEN
}

get_secrets() {
  # If this pod didnt initialized Vault, then it wont have access to the root_token or unseal key,
  # so we need to look them up from a Kubernetes secret.
  SECRET_ROOT_TOKEN=$(kubectl get secrets vault-token -o json | jq -r '.data.root_token' | base64 -d)
  SECRET_UNSEAL_KEY=$(kubectl get secrets vault-token -o json | jq -r '.data.unseal_key' | base64 -d)
}

mount_auth() {
  echo "userpass/ auth method not detected, attempting to mount"
  vault auth enable userpass
  vault write auth/userpass/users/admin password=password policies=admins
  echo 'path "*" {capabilities = ["create", "read", "update", "delete", "list", "sudo"]}' | vault policy write admins -
}

# Check Vault status before we start
check_status
check_mount

if [ "$INIT" = "true" ] && [ "$SEAL" = "false" ] && [ ! -n "$USERPASS" ]; then
  echo "Vault is already initialized, unsealed and has userpass mounted. Nothing to do here..."
  sleep 10
else

  # Beginning of the retry loop
  for i in {1..10}; do

    echo "Attempt number $i ..."
    check_status
  
    # If vault is not initialized and you are pod-0 then initialize it.
    if [ "$INIT" = "false" ] && [ "$HOSTNAME" = "vault-0" ]; then 
      init_vault
    else
      echo "Vault is already initialized, skipping..."
    fi
    
    # Initialization can take some time to complete
    sleep 10

    # Allow extra time for kubernetes secret to be saved.
    if [ "$HOSTNAME" != "vault-0" ]; then
      sleep 10
    fi

    check_status
    get_secrets


    # Wait for Vault to be initialized
    until [ "$INIT" = "true" ]; do
      echo "Waiting for Vault to be initialized"
      check_status
      sleep 5
    done

  
    # If vault is sealed, unseal it.
    if [ "$SEAL" = "true" ]; then 
      unseal_vault
    else
      echo "Vault is already unsealed. skipping..."
    fi
  
    check_status
    check_mount
    
    # If vault is initialized and unsealed, create some initial users
    if [ "$INIT" = "true" ] && [ "$SEAL" = "false" ] && [ "$HOSTNAME" = "vault-0" ] && [ -n "$USERPASS" ]; then 
      echo "Vault is initialized and unsealed, attempting to create bootstrap users."
      mount_auth
    else
      echo "userpass/ auth method already mounted. skipping..."
    fi
  
  done
fi

echo "Vault auto-init end."
while true; do sleep 10000; done
