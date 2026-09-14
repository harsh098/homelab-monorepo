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
  `openbao.platform.home.arpa`, `keycloak.platform.home.arpa`,
  `traefik.platform.home.arpa`, and `kube-api.platform.home.arpa` ->
  `192.168.10.220`.
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
- **04-platform** deploys Traefik, OpenBao, and Keycloak after compute and K3s
  API readiness succeed. It is the platform cluster layer, not a generic
  application deployment layer. The recovery workflow reconciles it
  automatically.
  Traefik is the ingress controller and is exposed through the K3s
  `LoadBalancer` service at `192.168.10.220`. Keycloak is a production-ish
  deployment with generated Kubernetes secrets and persistent 8Gi PostgreSQL
  storage. OpenBao remains in development mode and is not suitable for
  production use.

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
`192.168.1.0/24`. AdGuard itself binds on `192.168.1.4`, but the Keycloak and
OpenBao hostnames require one of the following before they can be reached from
other LAN devices: a home-router static route to `192.168.10.0/24` via
`192.168.1.4`, host/firewall DNAT or a reverse proxy, or a LAN-reachable VM NIC.
DNS answers alone do not establish application reachability from LAN devices.
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
`terraform/layers/04-platform` (Traefik, OpenBao, and Keycloak) in that order.
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
The platform layer installs cert-manager, loads the retained
`homelab-private-ca` Google Cloud Secret Manager bundle into the cluster, and
uses it as the CA for Keycloak and OpenBao ingress certificates.

### Keycloak bootstrap credential recovery

The platform layer stores the existing Keycloak bootstrap admin credential
as one initial, immutable JSON bundle in Google Cloud Secret Manager for
recovery only. The bundle contains `schema_version`, `username`, and
`password`; protect Terraform state, GCP access, and Secret Manager IAM. Never
store user passwords in this recovery secret.

The `Platform` realm now contains dedicated `kubectl-readonly` and
`kubectl-admin` roles and groups. The `kubernetes` client uses browser
authorization-code flow with PKCE, an exact loopback callback, and a
multivalued `groups` claim assembled from both group membership and direct
Platform realm-role assignments. Assigning either Platform realm role directly
therefore grants the corresponding Kubernetes access; groups remain useful for
bulk assignment. The K3s API maps `oidc:kubectl-readonly` to the built-in
`view` role and `oidc:kubectl-admin` to the repository's least-privilege
`platform-operator` role. The helper never uses the password grant.

The Kubernetes `keycloak-admin` Secret is bootstrap input only. Changing that
Secret does not rotate an initialized realm; use a break-glass Keycloak Admin
Console/API session for rotation and protect Terraform state, GCP access, and
Secret Manager IAM.

Google IdP credentials remain in the per-application
`keycloak-google-oauth` Secret and are not embedded in the kubectl helper.

#### First Google login and an existing account

The GitOps reconciler does not pre-create the configured Google administrator.
It waits for an authenticated Google broker login to provision the Keycloak
user, then assigns that existing user to the `kubectl-admin` group. If the user
does not exist yet, reconciliation intentionally does nothing; the next
five-minute run grants access after Google creates the account. This is not
automatic account linking: matching an email address is never used to merge a
Google identity with a local account.

If an older reconciliation already created `hmisraji07@gmail.com` and Google
login reports `Account already exists`, first apply this updated reconciler. If
the old CronJob is still active and can run before the update, suspend it before
deleting the user:

```bash
kubectl -n keycloak patch cronjob keycloak-gitops-reconciler \
  --type merge -p '{"spec":{"suspend":true}}'
```

Use the Keycloak Admin Console's **Platform → Users** page to remove that
unused pre-created local user, resume the updated CronJob if it was suspended,
wait for (or manually trigger) the reconciler, and retry Google login. Google
will then create the user and the following reconciliation will assign the
`kubectl-admin` group and its `kubectl-admin` realm role. Delete the old user
only after confirming it has no credentials or application data that must be
retained.

If the existing account must be retained, authenticate that local account and
manually link the verified Google identity through Keycloak's account/identity
provider linking flow (an administrator may first set a temporary local
password and require it to be changed). Verify the Google account and provider
subject, not merely the email text, before linking. Do not enable or implement
an automatic first-login flow that links accounts based only on email. After a
successful manual link, the reconciler will find the existing user and assign
the admin group on its next run.

Before the first browser login, install the retained public CA certificate
`~/.config/homelab/keycloak-ca.crt` in the workstation/browser trust store.
The helper trusts this file directly, but browsers do not automatically trust
private CAs. Additional users can be assigned either Platform realm role
directly or placed in the corresponding `kubectl-readonly` or `kubectl-admin`
group.

The host-side bootstrap-to-OIDC transition is performed by `ansible/site.yml`;
it installs the Keycloak CA for K3s discovery and the browser helper/kubeconfig,
then configures and restarts K3s. Keycloak realms, the Platform/Homelab Google
identity providers, the Kubernetes client/mappers, and the Kubernetes RBAC
manifests are reconciled by the Flux Kustomization rooted at
`clusters/platform` once Flux has been bootstrapped. A platform-only OpenTofu
apply still does not restart K3s or install the browser-authenticated kubeconfig.

This repository declares the Flux source and Kustomization but does not
install the Flux controllers. The initial bootstrap must install those
controllers and apply `clusters/platform/flux-source.yaml`; subsequent
changes are reconciled from the repository by Flux.

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
kubectl -n openbao get certificate,secret openbao.platform.home.arpa-tls

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

Do not apply the platform layer until the K3s API is reachable through
