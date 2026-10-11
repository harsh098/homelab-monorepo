# Homelab

This repository provisions a small, single-node Ubuntu K3s homelab. Ansible owns the host/libvirt setup; OpenTofu manages the Terraform layers after the compute node is available.

## Prerequisites

- Access to libvirt/KVM on the host
- Ansible with the `community.libvirt` collection
- OpenTofu (`tofu`)
- An SSH key usable for the Ubuntu node
- GCS authentication for the configured Terraform backend

## Provision the compute node

Ansible creates or reconciles the `homelab-dir` libvirt storage pool at
`/var/tmp/homelab-libvirt` and the desired routed management network
`192.168.10.0/24`. An existing live NAT `mgmt` network remains in place unless
the explicit routed-network migration is enabled. It creates or reconciles the
single Ubuntu K3s node and retains a private bootstrap kubeconfig at
`terraform/layers/03-compute/kubeconfig`.

```bash
ansible-playbook -i ansible/inventory.ini ansible/site.yml
```

The compute layer must complete successfully before applying the platform
layer. The bootstrap kubeconfig is used only by Ansible and the Kubernetes and
`~/.kube/config`, preserving other clusters, users, contexts, and the current
context. The `homelab-oidc` context contains only the API server CA metadata and
an exec-plugin reference; it contains no bootstrap client certificate or key.
The generated `client.authentication.k8s.io/v1` exec stanza sets
`interactiveMode: Never` because the helper opens a browser and uses a loopback
callback without reading stdin. kubectl obtains a short-lived Keycloak token
through the browser helper.

## Terraform layers

Terraform state is stored in the configured GCS backend. Layers are applied
individually from their directories:

- **01-infra** is intentionally empty.
- **02-dns** manages a rootful Docker AdGuard Home container on the host LAN
  address `192.168.1.4`. The image is pinned to
  `adguard/adguardhome:v0.107.79@sha256:aba9e3bf0613be3ba3755e1fc311b126e2c24bec25e18b6483894a88283074f0`.
  Terraform manages the persistent paths under
  `terraform/layers/02-dns/adguard-managed/`: the generated source
  `adguard.platform.home.arpa` -> `192.168.1.4`, and
  `keycloak.platform.home.arpa`, `openbao.platform.home.arpa`,
  `capacitor.platform.home.arpa`, `traefik.platform.home.arpa`, and
  `kube-api.platform.home.arpa` -> `192.168.10.220`.
  The `dns_records` variable is a `map(string)` of hostname-to-IP entries
  merged over these defaults, so caller-supplied entries override them.
  For example, add Grafana with:

  ```bash
  -var='dns_records={"grafana.platform.home.arpa"="192.168.10.220"}'
  ```

  Applying record changes recreates the managed AdGuard container to reload the
  generated configuration; the persistent `work/` directory is retained.

  The `.local` suffix is reserved for mDNS and should not be used for homelab
  DNS names; use `.platform.home.arpa` instead.
- **03-compute** contains the compute resources reconciled by the Ansible
  workflow above.
- **04-platform** bootstraps the platform prerequisites after compute and K3s
  API readiness succeed. Terraform owns the `keycloak` and operator
  prerequisite namespaces, cert-manager/CA material, ingress certificates,
  and External Secrets installation. Flux owns the CNPG operator, CNPG
  `Cluster`, Keycloak Operator, Keycloak CR, and create-only
  `KeycloakRealmImport`.
- The platform cluster layer is not a generic application deployment layer.
  Flux reconciles `clusters/platform/` through one platform Kustomization:
  `controllers/` holds controller-specific installations, `identity/` holds
  `keycloak-app/` and `keycloak-gitops/`, `secrets-management/` holds OpenBao,
  `apps/` holds user applications, and `policies/` holds platform safeguards.
  Traefik is exposed through the K3s `LoadBalancer` service at
  `192.168.10.220`. Keycloak 26.7.3 uses a CloudNativePG-managed PostgreSQL
  cluster and receives its TLS certificate from the retained private CA.




### Deploy AdGuard DNS

Run the following from the DNS layer directory:

```bash
cd terraform/layers/02-dns
tofu init
tofu plan -input=false \
  -var='host_lan_ip=192.168.1.4' \
  -var='k8s_ingress_ip=192.168.10.220' \
  -var='dns_domain=platform.home.arpa'
tofu apply -auto-approve -input=false \
  -var='host_lan_ip=192.168.1.4' \
  -var='k8s_ingress_ip=192.168.10.220' \
  -var='dns_domain=platform.home.arpa'
```

The home router's DHCP/LAN DNS setting must advertise `192.168.1.4` to LAN
clients for them to use AdGuard. Terraform cannot change a router whose
configuration and management interface are not specified here. Firewalld must
also allow inbound `53/tcp` and `53/udp` from external LAN clients. Current
DNS verification was host-side only; second-client reachability has not been
claimed or verified.

The `192.168.10.220` ingress address is on the current libvirt management
network; it is not automatically routable from home-LAN clients on
`192.168.1.0/24`. AdGuard itself binds on `192.168.1.4`; the Keycloak
hostname requires one of the following before it can be reached from other
LAN devices: a home-router static route to `192.168.10.0/24` via
`192.168.1.4`, host/firewall DNAT or a reverse proxy, or a LAN-reachable VM
NIC. DNS answers alone do not establish application reachability from LAN
devices.
For the current router's **Static Route** form, enter:

| Field | Value |
| --- | --- |
| Destination IP | `192.168.10.0` |
| Subnet Mask | `255.255.255.0` |
| Gateway | `192.168.1.4` |
| Interface | `LAN` |
| Metric | `1` (or the lowest value accepted) |

The K3s ingress/node address is `192.168.10.220`, not `192.168.10.20`.
The `/24` route covers that address; the narrower alternative is destination
`192.168.10.220` with mask `255.255.255.255`. A router route alone is still
insufficient: the host must also have its forwarding policy active. The
Ansible infrastructure playbook manages the narrow `lan-k3s-ingress` firewalld
policy, but it is not active until the privileged playbook run completes:

```bash
ansible-playbook -i ansible/inventory.ini ansible/infra.yml --ask-become-pass
```
After activation, the policy permits LAN TCP `80`, `443`, and `6443` from
`192.168.1.0/24` to `192.168.10.220` on the libvirt network. TCP 6443 is the
Kubernetes API and is not proxied through Traefik. Both the router route and
this host policy are required; the policy does not enable masquerading.
 
### Routed libvirt management network

The desired Terraform/Ansible configuration uses a **routed** `mgmt` network,
not NAT. An existing live NAT network is preserved until the migration is
explicitly opted into. When applied, the migration changes `mgmt` from NAT to
routed mode. In the current NAT configuration, libvirt rejects unsolicited
LAN-to-guest forwarding before the firewalld forwarding policy can evaluate it.
After migration, the intended LAN path is:

```text
LAN client -> 192.168.1.4/eno2 -> virbr3 -> 192.168.10.220
```

Install this exact static route on the home router before testing:

| Field | Value |
| --- | --- |
| Destination | `192.168.10.0/24` |
| Gateway | `192.168.1.4` |
| Interface | `LAN` |

No masquerading is used. Consequently, guest outbound traffic depends on the
home router having a return route for `192.168.10.0/24` via `192.168.1.4` (and
on upstream networks having appropriate return routing). Changing `mgmt` from
NAT to routed mode can interrupt the VM and its network while libvirt
reconfigures the bridge; plan a maintenance window and expect existing
connections to reset.

To migrate from NAT to routed mode, configure the router route above first and
schedule a maintenance window. The explicit extra variable is required; the
single recovery workflow performs the migration and subsequent reconciliation:

```bash
ansible-playbook -i ansible/inventory.ini ansible/site.yml \
  --ask-become-pass -e migrate_mgmt_network_to_routed=true
```

Verify the host and libvirt state:

```bash
virsh -c qemu:///system net-dumpxml mgmt
ip -4 route get 192.168.10.220
firewall-cmd --policy=lan-k3s-ingress --list-all
firewall-cmd --get-zone-of-interface=eno2
firewall-cmd --get-zone-of-interface=virbr3
```

From a LAN client, verify the route and only the intended web ports:

```bash
curl -v --connect-timeout 5 http://192.168.10.220/
curl -vk --connect-timeout 5 https://192.168.10.220/
```

The narrow `lan-k3s-ingress` policy must remain active: it permits only TCP
`80` and `443` from `192.168.1.0/24` to `192.168.10.220`. Do not replace it
with a broad zone `ACCEPT` or enable masquerading as a substitute for the
router route.

### Power outage recovery

The home router must have this static route before using the routed management
network. The route is an external prerequisite and is not changed by this
repository:

| Field | Value |
| --- | --- |
| Destination | `192.168.10.0/24` |
| Gateway | `192.168.1.4` |
| Interface | `LAN` |

From the repository root, run the single recovery workflow:

```bash
ansible-playbook -i ansible/inventory.ini ansible/site.yml --ask-become-pass
```

The workflow starts and enables the host services needed after an outage
(`firewalld`, Docker, and the libvirt `virtqemud` socket), reconciles and
autostarts the management network and compute domain, starts `k3s-node` if its
`/readyz` response is available. It then reconciles
`terraform/layers/02-dns` (AdGuard) and
`terraform/layers/04-platform` (Traefik and Keycloak) in that order.
OpenTofu is run locally by the Ansible localhost play; backend authentication
must already be available in the environment. The bootstrap kubeconfig remains
at `terraform/layers/03-compute/kubeconfig` with mode `0600` for automation
only; Ansible does not copy that cluster-admin credential to `~/.kube/config`.
It merges the `homelab-oidc` cluster, user, and context into
`~/.kube/config` and installs the helper and public Keycloak CA under
`~/.local/bin/` and `~/.config/homelab/`. The generated OIDC user entry
contains no bootstrap client certificate or private key; its v1 exec plugin is
declared non-interactive because authentication happens through the browser
callback. Entries carrying the merge utility's management marker are replaced
on each run. If an unmanaged entry already uses `homelab-oidc`, the generated
entries use the next available deterministic suffix (`homelab-oidc-2`, then
`-3`, and so on), leaving the collision untouched. The merge is written
atomically with mode `0600` and does not create a backup, avoiding extra copies
of credentials.

Use browser-authenticated kubectl access (the merge preserves your existing
current context, so select this context explicitly):

```bash
kubectl config use-context homelab-oidc
kubectl get nodes
```

The first kubectl call opens Keycloak in a browser, listens only on
`127.0.0.1:18000`, and caches only short-lived OIDC credentials with mode
`0600`. The old bootstrap config can be used by a break-glass operator with
`KUBECONFIG=terraform/layers/03-compute/kubeconfig`, but must not be shared.

The node address is discovered from its libvirt DHCP lease for SSH, while the
DNS and ingress configuration intentionally retain `192.168.10.220`. The
current workflow does not create a DHCP reservation; ensure the existing
libvirt lease remains stable (or add a reservation for the compute node's
configured MAC) before relying on LAN application reachability. If the lease
changes, the API wait can still succeed at the discovered address while the
fixed DNS rewrites and router route target no longer match.

An existing live NAT `mgmt` network is preserved by default. If the network
still needs to be migrated to routed mode, install the router route above
first, schedule the maintenance window, and explicitly opt in:

```bash
ansible-playbook -i ansible/inventory.ini ansible/site.yml \
  --ask-become-pass -e migrate_mgmt_network_to_routed=true
```

Only that explicit flag permits stopping and undefining an existing NAT
definition. Without it, the workflow does not perform NAT-to-routed
migration. A routed network provides no masquerading, so return routing
through `192.168.1.4` remains required.

The workflow does not apply the DNS or platform layers until the K3s API
readiness check succeeds. To inspect the resulting state:

```bash
virsh -c qemu:///system net-info mgmt
docker ps --filter name=adguardhome
KUBECONFIG=terraform/layers/03-compute/kubeconfig kubectl get nodes,pods,svc -A
```

Do not run a separate OpenTofu apply concurrently with the recovery workflow.
The platform layer installs cert-manager and loads the retained
`homelab-private-ca` Google Cloud Secret Manager bundle into the cluster for
the Keycloak ingress certificate.

### Keycloak bootstrap and OIDC provisioning

The platform layer stores the fresh operator bootstrap admin credential as one
initial, immutable JSON bundle in Google Cloud Secret Manager for recovery only.
The bundle contains `schema_version`, `username`, and `password`; protect
Terraform state, GCP access, and Secret Manager IAM. The Kubernetes Secret
`keycloak-operator-bootstrap` is consumed only during initial operator
reconciliation. Rotating it does not rotate an initialized Keycloak instance;
use a break-glass Admin Console/API session for rotation.

Keycloak is a fresh deployment managed by the official Keycloak Operator
26.7.3. Flux applies the official create-only `KeycloakRealmImport` for the
`Platform` realm, including the `kubernetes` public client, loopback
authorization-code + PKCE redirect URI, protocol mappers, and the initial
access-role names. Realm imports do not update or delete an existing realm.

Crossplane 2.4.1 and `provider-keycloak` 3.0.1 own ongoing `Platform` identity
state in `clusters/platform/identity/keycloak-gitops/identities.yaml`: realm roles,
groups, group-role mappings, users, and group memberships. Terraform supplies
`crossplane-system/keycloak-crossplane-credentials` from the Keycloak bootstrap
admin password; Flux installs the provider and its ProviderConfig. Apply the
platform Terraform layer before Flux. Rotate the admin password through the
Keycloak API and Terraform credential source together when replacing it.

Do not store user passwords in this repository or in the recovery secret.
Google remains the interactive authentication source. The operator does not
define an export CR; exports remain an explicit Keycloak CLI/API operation and
must not be treated as declarative user data.

#### Manual Google sign-in runbook

Google sign-in is an explicit day-two operation because
`KeycloakRealmImport` creates realms but does not update an existing realm.
This runbook uses the Keycloak Admin REST API directly and does not require a
Kubernetes kubeconfig.

1. In Google Cloud, create a **Web application** OAuth client and configure
   this exact authorized redirect URI:

   ```text
   https://keycloak.platform.home.arpa/realms/Platform/broker/google/endpoint
   ```

2. Store the OAuth credential as the latest
   `keycloak-google-oauth` Google Secret Manager version:

   ```json
   {
     "client_id": "<google-oauth-client-id>",
     "client_secret": "<google-oauth-client-secret>"
   }
   ```

3. Authenticate `gcloud`, install the homelab CA at
   `~/.config/homelab/keycloak-ca.crt`, and run:

   ```bash
   tools/configure-keycloak-google-idp.py
   ```

   Pass `--project <gcp-project-id>` when the required project is not the
   active `gcloud` project. To restrict sign-in to one Google Workspace
   organization, also pass `--hosted-domain example.com`.

The utility reads `keycloak-admin-recovery` and `keycloak-google-oauth`
directly from Secret Manager, keeps credentials in process memory, and
creates or updates the `google` identity provider idempotently. It never
prints or writes those credentials. Use `--dry-run` to authenticate and
report whether the provider would be created or updated without modifying
Keycloak.

#### GitOps role and user workflow

Edit `clusters/platform/identity/keycloak-gitops/identities.yaml` and push to `main`.
Each person has one `user.keycloak.crossplane.io/User`; access is the
authoritative `members` list on a
`group.keycloak.crossplane.io/Memberships` resource. Capacitor access is the
`platform-capacitor-members` list; Kubernetes administrator access is the
`platform-kubectl-admin-members` list. Add a corresponding
`platform-kubectl-readonly-members` resource when the first read-only user is
granted access; the provider requires at least one member and an absent
membership resource represents the currently empty group.

Create users without an `initialPassword`; Google establishes the federated
identity at first sign-in. For offboarding, first remove the username from all
membership lists and set `enabled: false`. Keep disabled imported users in Git
for auditability: imported users use `deletionPolicy: Orphan`, so deleting only
the Kubernetes resource does not delete the Keycloak account. Role and group
resources use `deletionPolicy: Delete`; removing one is therefore an explicit,
destructive access-model change.

Verify reconciliation without reading credentials:

```bash
KUBECONFIG=terraform/layers/03-compute/kubeconfig \
  kubectl get providers.pkg.crossplane.io provider-keycloak
KUBECONFIG=terraform/layers/03-compute/kubeconfig \
  kubectl get roles.role.keycloak.crossplane.io,groups.group.keycloak.crossplane.io
KUBECONFIG=terraform/layers/03-compute/kubeconfig \
  kubectl get users.user.keycloak.crossplane.io,memberships.group.keycloak.crossplane.io
```

To make an operational realm backup, use the supported Keycloak export command
outside Flux (preferably during a maintenance window):

```bash
KUBECONFIG=terraform/layers/03-compute/kubeconfig \
  kubectl -n keycloak exec keycloak-0 -- \
  /opt/keycloak/bin/kc.sh export --realm Platform \
  --file=/tmp/platform-realm-export.json
KUBECONFIG=terraform/layers/03-compute/kubeconfig \
  kubectl -n keycloak cp keycloak-0:/tmp/platform-realm-export.json \
  ./platform-realm-export.json
```

Treat that file as an operational backup, not a Flux-managed input; it may
contain user and client credentials.

The K3s API and browser helper retain the existing OIDC contract:
`https://keycloak.platform.home.arpa/realms/Platform` is the issuer and
`kubernetes` is the client ID. Assign users the required `kubectl-readonly` or
`kubectl-admin` realm/group claims as part of the separate provisioning
workflow. The repository's OIDC RBAC bindings continue to map those groups to
cluster access.

### Deploy Headlamp

The platform Flux layer installs Headlamp from the official Helm repository and
publishes it at `https://headlamp.platform.home.arpa` behind the Traefik
ingress. Headlamp uses the Keycloak `Platform` realm with the `headlamp`
confidential client and passes each user's OIDC token to Kubernetes; the
service account has no cluster RBAC binding.

Users must be members of the `kubectl-admin` or `kubectl-readonly` Keycloak
group. The Kubernetes API applies the corresponding OIDC RBAC policy.

The OIDC callback is:

```text
https://headlamp.platform.home.arpa/oidc-callback
```

The dashboard is also available locally when needed:

```bash
KUBECONFIG=terraform/layers/03-compute/kubeconfig \
  kubectl -n kube-system port-forward service/headlamp 8080:80
```

Apply and verify the platform layer:

```bash
cd terraform/layers/04-platform
tofu init
tofu plan -input=false
tofu apply -auto-approve -input=false

# Verify cert-manager and issued application certificates.
kubectl -n cert-manager get deployment cert-manager
kubectl get clusterissuer homelab-private-ca
kubectl -n keycloak get certificate,secret keycloak.platform.home.arpa-tls

# Verify the retained recovery secret without printing secret data.
gcloud secrets versions list homelab-private-ca --project="$GCP_PROJECT_ID"
```

The recovery workflow applies the platform layer only after the K3s API
readiness check. For a manual platform-only reconciliation, after confirming
the API is reachable through the fetched kubeconfig:
```bash
cd terraform/layers/04-platform
tofu init
tofu plan -input=false
tofu apply -auto-approve -input=false
```


### Keycloak database credentials

`05-gcp` stores the existing Keycloak PostgreSQL password in the dedicated
`keycloak-db-credentials` Secret Manager secret. The `keycloak` namespace's
`keycloak-db-credentials` ExternalSecret reads it through the existing
`gcp-secret-manager` ClusterSecretStore. Preserve the Terraform-managed
`random_password.keycloak_db_password` state and the Secret Manager version
when recovering the database: regenerating the password without changing
PostgreSQL breaks Keycloak logins. This GCP bootstrap dependency must remain
available independently of any future secrets manager.

### OpenBao

Flux installs OpenBao 2.7.1 using chart 0.30.3 in `openbao`. The Helm chart's
Raft mode requires `ha.enabled`, but `replicas: 1` runs exactly one server:
there is no high availability. Its 8Gi PVC uses `local-path-retain`; the PV
and its data remain if the Helm release is removed. Traefik serves
`https://openbao.platform.home.arpa` with the homelab private CA.

Clients must trust the homelab private CA. On Fedora, install only its public
certificate and restart the browser:

```bash
KUBECONFIG=terraform/layers/03-compute/kubeconfig \
  kubectl -n cert-manager get secret homelab-private-ca \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/homelab-ca.crt
sudo install -m 0644 /tmp/homelab-ca.crt \
  /etc/pki/ca-trust/source/anchors/homelab-ca.crt
sudo update-ca-trust
```

OpenBao auto-unseals through the first-party GCP KMS plugin. The dedicated
`openbao-unseal-in` key ring and key in `asia-south1` are protected against
accidental Terraform destruction. A scoped `openbao-unseal` service account
can only inspect, encrypt, and decrypt with that key. External Secrets syncs
its JSON credential from the `openbao-kms-credentials` GCP secret into the
`openbao` namespace; OpenBao mounts it read-only. The service account key
is sensitive Terraform state, not a Git-managed value.

The original one-share Shamir seal was migrated to GCP KMS. Its share became
the recovery key and remains, along with the initial root token, in the
`openbao-recovery` GCP Secret Manager version. The JSON field is still named
`unseal_keys_b64` because it is the original initialization record; **do not
use it to manually unseal this KMS-sealed server**. Terraform manages only
the recovery secret container, not that version. Keep access restricted.

After a restart, OpenBao unseals automatically if GCP KMS and its credential
are reachable. Check with:

```bash
KUBECONFIG=terraform/layers/03-compute/kubeconfig \
  kubectl -n openbao exec openbao-0 -- bao status
```

Never disable or destroy any KMS key version used by this seal. Recovery
shares cannot decrypt OpenBao without the KMS key, even from a Raft backup.

For normal operator sign-in, select **OIDC** at the OpenBao UI, leave the role
blank (default `platform-operators`), and authenticate through the Keycloak
`Platform` realm. The `openbao` confidential client, `openbao-admin` group,
membership, and group claim mapper are managed by Crossplane through Flux.
Only members of `openbao-admin` receive the OpenBao operator policy. The
group's membership list is in
`clusters/platform/identity/keycloak-gitops/openbao-oidc.yaml`.

Two GitOps-managed confidential clients publish their generated `clientID`
and `clientSecret` from Crossplane connection Secrets in `keycloak` through
separate namespaced ESO `PushSecret` resources:

| Client | Connection Secret | OpenBao KV v2 path |
| --- | --- | --- |
| `openbao` | `keycloak/openbao-oidc-client` | `platform/keycloak/clients/openbao` |
| `headlamp` | `keycloak/headlamp-oidc-client` | `platform/keycloak/clients/headlamp` |

Each publisher uses its own Kubernetes service account, auth role, and policy
restricted to its single KV path. No client secret or OpenBao token is stored
in Git. The `kubernetes` client is public and has **no client secret** to
publish; Keycloak's built-in administrative clients are not application
credentials. For another confidential client, declare the Crossplane client
and connection Secret, then add a separate publisher, path, role, and policy.
Publishing Headlamp's client credential does not configure Headlamp's
`kube-system/headlamp-oidc` runtime Secret; that consumer still needs its own
delivery path.

The OIDC and Kubernetes auth mounts, KV mount, roles, and policies require
privileged initial configuration; Flux must not hold the root token.
After Crossplane has produced `keycloak/openbao-oidc-client` and the OpenBao
Helm release is ready, run from the repository root with `gcloud` access,
the bootstrap kubeconfig, and the private CA at
`~/.config/homelab/keycloak-ca.crt`:

```bash
tools/configure-openbao-access.py
KUBECONFIG=terraform/layers/03-compute/kubeconfig \
  kubectl -n keycloak get pushsecrets \
  openbao-oidc-client headlamp-oidc-client \
  -o custom-columns=NAME:.metadata.name,READY:.status.conditions[0].status
```

The idempotent utility reads the recovery root token from GCP Secret Manager
and the OIDC client secret from the Kubernetes connection Secret into process
memory; it does not print either. Rerun it after rotating the Keycloak client
secret. Keep the initial root token in GCP as break-glass access when Keycloak
is unavailable; do not use it for normal login. To retrieve it privately for
emergency use (this command **prints a privileged credential**):

```bash
gcloud secrets versions access latest --secret=openbao-recovery \
  --project=learninggcp-470023 |
  python3 -c 'import json,sys; print(json.load(sys.stdin)["root_token"])'
```

OpenBao Raft is snapshotted every six hours (UTC) by
`openbao/openbao-backup`. Its Kubernetes auth role can only read
`sys/storage/raft/snapshot`; the job uploads a unique object to
`gs://hmx-openbao-backups-in/raft/` and verifies the remote SHA-256 and length
before succeeding. Its GCP identity cannot delete objects. Do not confuse this
off-node copy with the retained local PVC. The snapshot contains secrets:
restrict access to the bucket, its GCP Secret Manager credential
`openbao-backup-gcs`, and the Terraform state.

Keycloak's CNPG `ScheduledBackup` (`keycloak-db-daily`) creates a PostgreSQL
base backup each day at 02:00 (the CNPG controller's time zone), with
continuous WAL archival by the Barman Cloud plugin. Both are stored under
`gs://hmx-keycloak-backups-in/keycloak/keycloak-db/`. The Barman GCP identity
has only bucket-scoped read, write, multipart upload, and overwrite rights;
overwrites of `backup.info` require `storage.objects.delete`. The bucket
versions overwritten objects. A separate GCP KMS key encrypts each bucket:
`platform-backups-in/openbao-backups-in` and
`platform-backups-in/keycloak-backups-in` in `asia-south1`, respectively.
Neither backup uses the OpenBao auto-unseal key. Both buckets have 14-day
GCS retention and soft deletion, plus 90-day lifecycle cleanup (including
noncurrent Keycloak generations). Keep backup KMS key versions enabled: GCS
cannot read CMEK-encrypted objects after a required key version is disabled.
These keys, buckets, bucket IAM, and backup service account keys are in
`terraform/layers/05-gcp/platform-backups.tf`. The credentials live in GCP
Secret Manager and are synced into Kubernetes by External Secrets; restoring
either backup does not require a working OpenBao instance.

Run and inspect an OpenBao backup without waiting for the next schedule:

```bash
KUBECONFIG=terraform/layers/03-compute/kubeconfig
export KUBECONFIG
backup_job="openbao-backup-manual-$(date +%s)"
kubectl -n openbao create job "$backup_job" --from=cronjob/openbao-backup
kubectl -n openbao wait --for=condition=complete "job/$backup_job" --timeout=180s
kubectl -n openbao logs "job/$backup_job" -c backup
gcloud storage ls -l gs://hmx-openbao-backups-in/raft/
```

For Keycloak, create a one-off `postgresql.cnpg.io/v1` `Backup` in `keycloak`
with `spec.cluster.name: keycloak-db`, `spec.method: plugin`, and
`spec.pluginConfiguration.name: barman-cloud.cloudnative-pg.io`. Wait for
`.status.phase: completed`; check that GCS contains both `base/<backup-id>/`
and `wals/` under the Keycloak path. A failed `Backup` or an archived WAL
alone does not prove that a recoverable base backup exists. Confirm object
`kms_key` with `gcloud storage objects describe gs://... --format=json`.

Restore drills must never reuse the production OpenBao PVC or CNPG cluster
name. For OpenBao, start a disposable Raft server and empty data volume in
a different namespace with the **same GCP unseal KMS plugin/configuration**,
using an ExternalSecret for `openbao-kms-credentials`. Initialize the empty
auto-unseal server with one recovery share, download a snapshot from GCS,
then send it to that disposable server's
`sys/storage/raft/snapshot-force` endpoint with its disposable root token.
Force is necessary because the new server has different barrier keys; do
not send a snapshot to the production endpoint. After restore, authenticate
with the original root token in the `openbao-recovery` GCP secret and read
`platform/keycloak/clients/openbao` (check keys, not secret values). Keep
snapshot bytes and privileged tokens off persistent local storage and logs;
delete the disposable namespace afterward. This was exercised with a fresh
emptyDir-backed server, without changing `openbao/openbao-0`.

For an isolated Keycloak restore, while `keycloak/keycloak-gcs` and its
ExternalSecret are healthy, apply a **new** CNPG `Cluster` in `keycloak`:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: keycloak-db-restore-drill
  namespace: keycloak
spec:
  instances: 1
  imageName: ghcr.io/cloudnative-pg/postgresql:17
  bootstrap:
    recovery:
      source: keycloak-db-source
  externalClusters:
    - name: keycloak-db-source
      plugin:
        name: barman-cloud.cloudnative-pg.io
        parameters:
          barmanObjectName: keycloak-gcs
          serverName: keycloak-db
  storage:
    size: 8Gi
    storageClass: local-path
```

Wait for `kubectl -n keycloak wait --for=condition=Ready
cluster/keycloak-db-restore-drill --timeout=240s`, then query the restored
database without exposing credentials:

```bash
kubectl -n keycloak exec keycloak-db-restore-drill-1 -c postgres -- \
  psql -U postgres -d keycloak -At \
  -c "SELECT name, (SELECT count(*) FROM client WHERE realm_id = realm.id) AS clients FROM realm WHERE name = 'Platform';"
```

This recovery cluster has no WAL archiver: it must **not** write to the source
archive. Delete only the disposable cluster and its `local-path` PVC after
verification. For a real cutover, retain the restored PVC, configure a
distinct backup destination before enabling archival, and switch Keycloak's
database connection explicitly. Preserve `keycloak-db-credentials` in GCP;
recreating its password independently of PostgreSQL breaks Keycloak logins.


### Stateful database safety

The Keycloak PostgreSQL cluster is protected by
`clusters/platform/policies/database-safety.yaml`.

- `ValidatingAdmissionPolicy` blocks deletion of the CNPG clusters and their
  PVCs.
- `local-path-retain` is the StorageClass for newly created platform database
  volumes.
- Existing database PVs have been changed to `Retain`.
- Flux prune is disabled on the CNPG Cluster resources.

Do not remove a protected database resource to force reconciliation. Recovery
must restore the existing PVC or restore a verified CNPG backup into a new
cluster, then switch the application explicitly.

Crossplane does not protect database data. In this repository it provisions
Keycloak API objects such as clients, groups, roles, and protocol mappers.
Those are control-plane resources stored in Keycloak's PostgreSQL database.
Crossplane cannot restore a deleted CNPG PVC, reconstruct Keycloak realm data,
or prevent another controller from deleting the database. Database durability
belongs to CNPG, storage reclaim policy, backup/restore, and admission
controls.
