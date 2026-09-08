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
single Ubuntu K3s node and fetches its kubeconfig to
`terraform/layers/03-compute/kubeconfig`.

```bash
ansible-playbook -i ansible/inventory.ini ansible/site.yml
```

The compute layer must complete successfully before applying the application
layer. The fetched kubeconfig is required by the Kubernetes and Helm providers.

## Terraform layers

Terraform state is stored in the configured GCS backend. Layers are applied
individually from their directories:

- **01-infra** is intentionally empty.
- **02-dns** manages a rootful Docker AdGuard Home container on the host LAN
  address `192.168.1.4`. The image is pinned to
  `adguard/adguardhome:v0.107.79@sha256:aba9e3bf0613be3ba3755e1fc311b126e2c24bec25e18b6483894a88283074f0`.
  Terraform manages the persistent paths under
  `terraform/layers/02-dns/adguard-managed/`: the generated source
  `AdGuardHome.yaml`, the writable AdGuard `conf/` directory, and the writable
  `work/` directory. AdGuard publishes TCP and UDP port 53 and HTTP ports 80
  and 3000 on `192.168.1.4`. Its default rewrites are:
  `adguard.platform.home.arpa` -> `192.168.1.4`, and
  `openbao.platform.home.arpa`, `keycloak.platform.home.arpa`, and
  `traefik.platform.home.arpa` -> `192.168.10.220`.
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

After activation, the policy permits only TCP `80` and `443` from
`192.168.1.0/24` on the LAN to `192.168.10.220` on the libvirt network. Both
the router route and this host policy are required; the policy does not enable
masquerading.
 
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
must already be available in the environment. The fetched kubeconfig is saved
to `terraform/layers/03-compute/kubeconfig` with mode `0600` and copied to the
invoking user's `~/.kube/config` (creating `~/.kube` with mode `0700`). Its
contents are not printed by Ansible.

For an immediate one-shell fallback, from the repository root:

```bash
export KUBECONFIG="$PWD/terraform/layers/03-compute/kubeconfig"
kubectl get nodes
```

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

The Kubernetes `keycloak-admin` Secret is only bootstrap input. Changing that
Secret does not rotate an admin password in an already initialized Keycloak
realm. Use a break-glass session to rotate the credential through the Keycloak
Admin Console or API, then deliberately create a new Secret Manager version
through the documented recovery procedure. Do not make a password rotation
call from Terraform.

Future OIDC client secrets must be stored one per application, with each
client scoped to its target realm and application. Google IdP and Kubernetes
OIDC are not configured here because the target realm, client IDs, and Google
OAuth credentials are not provisioned.

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
