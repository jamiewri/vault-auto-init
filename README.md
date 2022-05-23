# vault-auto-init

## Purpose
Vault-auto-init is a container used to bootstrap [HashiCorp Vault](https://www.hashicorp.com/products/vault) running in Kubernetes. I use it when working in a development environment where it is useful to be able to get Vault running quickly. It does **not** follow recommended practices for configuring Vault in a production environment.

When mounted as a side car to Vault, vault-auto-init will do the following:
- Initialize Vault with 1 key share and 1 key threshold.
- Unseal Vault.
- Save the `root_token` and `unseal_key` into a Kubernetes secret.
- Mount the userpass auth method.
- Create a user admin with the password of 'password'. 

> :warning: If you are using Vault in production, take a look at the [auto-unseal](https://www.vaultproject.io/docs/concepts/seal#auto-unseal) options.

## Usage
If you are using the [vault-helm](https://github.com/hashicorp/vault-helm) chart to deploy vault, here are the additions you need to make to the `values.yaml` file.
```yaml
server:
  # This service account needs to be created prior to deploying Vault and needs
  # the privileges to read and write secrets in the current namespace.
  serviceAccount:
    create: false
    name: "vault-operator"

  extraContainers:
    - name: autoinit
      image: "jamiewri/vault-auto-init:0.1"
      command: [sh, -c]
      args:
        - sh /tmp/init.sh
```

Example Kubernetes secret created.
```yaml
kubectl get secret vault-token -o yaml
apiVersion: v1
data:
  root_token: dGhpc3Rva2VuaXNuZXZlcmdvaW5ndG93b3JrCg==
  unseal_key: cTNmNTNvRllFNm1URzc5bmpLbjkrT1pRSkl5TWNlUmQ5QWtyVXgvZlUvND0=
kind: Secret
metadata:
  name: vault-token
  namespace: infra
type: Opaque
```

## Todo
- [ ] Move to clean alpine container.
- [ ] Clean up entrypoint
- [ ] Support more than 3 replicas in a deployment.
- [ ] Provide ServiceAccount, RoleBinding and Role examples.
- [ ] Support running this container as a job.
- [ ] Rewrite in Go using the [offical Vault SDK](https://github.com/hashicorp/vault/tree/main/api).
- [ ] Support user provided configuration.

