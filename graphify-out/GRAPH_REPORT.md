# Graph Report - llm-studio  (2026-10-22)

## Corpus Check
- 84 files · ~158,911 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 11 file(s) not represented in the graph (top: (none) 3, .tftpl 2, .cfg 1)

## Summary
- 409 nodes · 604 edges · 58 communities (26 shown, 17 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 11 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `59daef1f`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- pki.tf
- 03-compute/variables.tf
- keycloak.tf
- 02-dns/main.tf
- kubernetes_manifest.gcp_secret_store
- 05-gcp/secrets.tf
- 04-platform/.terraform.lock.hcl
- 02-dns/.terraform.lock.hcl
- 05-gcp/.terraform.lock.hcl
- var.project_id
- provider.registry.opentofu.org/dmacvicar/libvirt
- provider.docker
- 03-compute/.terraform.lock.hcl
- provider.google
- build-image.sh
- What You Must Do When Invoked
- graphify reference: extra exports and benchmark
- Terraform layers
- graphify reference: query, path, explain
- Platform OS
- graphify reference: add a URL and watch a folder
- graphify reference: commit hook and native CLAUDE.md integration
- graphify reference: incremental update and cluster-only
- AGENTS.md
- graphify reference: GitHub clone and cross-repo merge
- graphify reference: transcribe video and audio
- extraction-spec.md
- kubectl-keycloak-login.py
- merge-kubeconfig.py
- RuntimeError
- cloudflare_zero_trust_tunnel_cloudflared_config.this
- build-headlamp-oidc-image.sh
- module.trilium_ingress
- vault_generic_endpoint.cloudflare_metadata
- 07-apps/.terraform.lock.hcl
- provider.registry.opentofu.org/hashicorp/vault
- provider.vault
- cloudflare_dns_record.this
- google_secret_manager_secret.keycloak_db_credentials
- trilium.tf
- backup-trilium.py
- restore-trilium.py
- provider.registry.opentofu.org/hashicorp/google

## God Nodes (most connected - your core abstractions)
1. `var.project_id` - 18 edges
2. `What You Must Do When Invoked` - 12 edges
3. `main()` - 11 edges
4. `local.platform_backups` - 10 edges
5. `OIDCError` - 10 edges
6. `/graphify` - 10 edges
7. `Terraform layers` - 10 edges
8. `_browser_login()` - 9 edges
9. `merge_kubeconfig()` - 9 edges
10. `var.project_id` - 8 edges

## Surprising Connections (you probably didn't know these)
- `docker_container.adguardhome` --references--> `var.host_lan_ip`  [EXTRACTED]
  terraform/layers/02-dns/main.tf → terraform/layers/02-dns/variables.tf
- `libvirt_volume.mail_data` --references--> `var.pool_name`  [EXTRACTED]
  terraform/layers/03-compute/mail-archive.tf → terraform/layers/03-compute/variables.tf
- `libvirt_volume.k8s_node` --references--> `var.disk_size`  [EXTRACTED]
  terraform/layers/03-compute/main.tf → terraform/layers/03-compute/variables.tf
- `libvirt_cloudinit_disk.k8s_cloudinit` --references--> `var.k8s_api_hostname`  [EXTRACTED]
  terraform/layers/03-compute/main.tf → terraform/layers/03-compute/variables.tf
- `libvirt_cloudinit_disk.k8s_cloudinit` --references--> `var.ssh_public_key_path`  [EXTRACTED]
  terraform/layers/03-compute/main.tf → terraform/layers/03-compute/variables.tf

## Import Cycles
- None detected.

## Communities (58 total, 17 thin omitted)

### Community 0 - "pki.tf"
Cohesion: 0.19
Nodes (15): data.google_secret_manager_secret.private_ca, data.google_secret_manager_secret_version.private_ca, helm_release.cert_manager, helm_release.traefik, kubernetes_manifest.cert_manager, kubernetes_manifest.keycloak_certificate, kubernetes_manifest.private_ca_cluster_issuer, kubernetes_secret_v1.cert_manager_ca (+7 more)

### Community 1 - "03-compute/variables.tf"
Cohesion: 0.13
Nodes (20): libvirt_cloudinit_disk.k8s_cloudinit, libvirt_domain.k8s_node, libvirt_volume.k8s_node, libvirt_volume.mail_data, libvirt_volume.ubuntu_base, output.k8s_node_ip, output.k8s_node_mac, output.kubeconfig_path (+12 more)

### Community 2 - "keycloak.tf"
Cohesion: 0.28
Nodes (11): google_secret_manager_secret.keycloak_admin_recovery, google_secret_manager_secret_version.keycloak_admin_recovery_initial, kubernetes_manifest.keycloak, kubernetes_secret_v1.keycloak_admin, kubernetes_secret_v1.keycloak_crossplane_credentials, local.keycloak_admin_recovery_bundle, local.keycloak_admin_username, output.keycloak_admin_recovery_secret_name (+3 more)

### Community 3 - "02-dns/main.tf"
Cohesion: 0.24
Nodes (15): docker_container.adguardhome, docker_image.adguard, local.config_dir, local.config_file, local.default_dns_records, local.dns_records, local_file.adguard_config, local.managed_data_dir (+7 more)

### Community 4 - "kubernetes_manifest.gcp_secret_store"
Cohesion: 0.31
Nodes (7): helm_release.external_secrets, kubernetes_manifest.external_secrets, kubernetes_manifest.gcp_secret_store, provider.google, provider.helm, provider.kubernetes, var.gcp_project_id

### Community 5 - "05-gcp/secrets.tf"
Cohesion: 0.47
Nodes (5): google_secret_manager_secret.backup_credentials, google_secret_manager_secret.backup_encryption_key, google_secret_manager_secret.keycloak_google_oauth, google_secret_manager_secret_version.backup_encryption_key_version, random_password.backup_key

### Community 6 - "04-platform/.terraform.lock.hcl"
Cohesion: 0.40
Nodes (4): provider.registry.opentofu.org/hashicorp/google, provider.registry.opentofu.org/hashicorp/helm, provider.registry.opentofu.org/hashicorp/kubernetes, provider.registry.opentofu.org/hashicorp/random

### Community 9 - "var.project_id"
Cohesion: 0.12
Nodes (33): data.google_project.current, google_artifact_registry_repository.headlamp, google_artifact_registry_repository_iam_member.headlamp_public_pull, google_kms_crypto_key_iam_member.mail_backup_gcs_service_agent, google_kms_crypto_key_iam_member.openbao_unseal, google_kms_crypto_key_iam_member.platform_backup_gcs_agent, google_kms_crypto_key.mail_backups, google_kms_crypto_key.openbao_unseal (+25 more)

### Community 27 - "What You Must Do When Invoked"
Cohesion: 0.08
Nodes (24): For /graphify add and --watch, For /graphify query, For the commit hook and native CLAUDE.md integration, For --update and --cluster-only, /graphify, Honesty Rules, Interpreter guard for subcommands, Part A - Structural extraction for code files (+16 more)

### Community 28 - "graphify reference: extra exports and benchmark"
Cohesion: 0.22
Nodes (8): graphify reference: extra exports and benchmark, Step 6b - Wiki (only if --wiki flag), Step 7 - Neo4j export (only if --neo4j or --neo4j-push flag), Step 7a - FalkorDB export (only if --falkordb or --falkordb-push flag), Step 7b - SVG export (only if --svg flag), Step 7c - GraphML export (only if --graphml flag), Step 7d - MCP server (only if --mcp flag), Step 8 - Token reduction benchmark (only if total_words > 5000)

### Community 29 - "Terraform layers"
Cohesion: 0.11
Nodes (17): Deploy AdGuard DNS, Deploy Headlamp, Deploy host applications: Trilium, GitOps role and user workflow, Homelab, Keycloak bootstrap and OIDC provisioning, Keycloak database credentials, Manual Google sign-in runbook (+9 more)

### Community 30 - "graphify reference: query, path, explain"
Cohesion: 0.33
Nodes (5): For /graphify explain, For /graphify path, graphify reference: query, path, explain, Step 0 — Constrained query expansion (REQUIRED before traversal), Step 1 — Traversal

### Community 31 - "Platform OS"
Cohesion: 0.40
Nodes (4): Benefits of this approach for Day 2 operations:, Building the Disk Image, Overview, Platform OS

### Community 32 - "graphify reference: add a URL and watch a folder"
Cohesion: 0.50
Nodes (3): For /graphify add, For --watch, graphify reference: add a URL and watch a folder

### Community 33 - "graphify reference: commit hook and native CLAUDE.md integration"
Cohesion: 0.50
Nodes (3): For git commit hook, For native CLAUDE.md integration, graphify reference: commit hook and native CLAUDE.md integration

### Community 34 - "graphify reference: incremental update and cluster-only"
Cohesion: 0.50
Nodes (3): For --cluster-only, For --update (incremental re-extraction), graphify reference: incremental update and cluster-only

### Community 39 - "kubectl-keycloak-login.py"
Cohesion: 0.19
Nodes (24): Namespace, _arguments(), _b64url(), _browser_login(), _CallbackHandler, _credential(), _expiration_timestamp(), _issuer() (+16 more)

### Community 40 - "merge-kubeconfig.py"
Cohesion: 0.28
Nodes (14): _atomic_dump(), _config(), _is_owned(), main(), _marker(), merge_kubeconfig(), _next_name(), _parser() (+6 more)

### Community 41 - "RuntimeError"
Cohesion: 0.14
Nodes (23): RuntimeError, _json_object(), main(), _parser(), Any, ArgumentParser, SSLContext, Create or update the Platform realm Google identity provider. Credentials are… (+15 more)

### Community 42 - "cloudflare_zero_trust_tunnel_cloudflared_config.this"
Cohesion: 0.33
Nodes (9): cloudflare_zero_trust_tunnel_cloudflared_config.this, cloudflare_zero_trust_tunnel_cloudflared.this, data.cloudflare_zero_trust_tunnel_cloudflared_token.this, module.dns_record, output.tunnel_token, var.account_id, var.hostname, var.origin_service (+1 more)

### Community 44 - "module.trilium_ingress"
Cohesion: 0.20
Nodes (8): module.trilium_ingress, output.trilium_tunnel_token, provider.cloudflare, provider.vault, var.cloudflare_account_id, var.cloudflare_zone_id, var.trilium_hostname, var.vault_token_file

### Community 52 - "cloudflare_dns_record.this"
Cohesion: 0.27
Nodes (8): cloudflare_dns_record.this, output.id, var.content, var.name, var.proxied, var.ttl, var.type, var.zone_id

### Community 53 - "google_secret_manager_secret.keycloak_db_credentials"
Cohesion: 0.70
Nodes (4): google_secret_manager_secret_iam_member.keycloak_db_credentials_reader, google_secret_manager_secret.keycloak_db_credentials, google_secret_manager_secret_version.keycloak_db_credentials, random_password.keycloak_db_password

### Community 54 - "trilium.tf"
Cohesion: 0.26
Nodes (13): data.google_project.current, google_kms_crypto_key_iam_member.trilium_backup_gcs_agent, google_kms_crypto_key.trilium_backups, google_kms_key_ring.trilium_backups, google_project_iam_custom_role.trilium_backup_writer, google_secret_manager_secret.trilium_backup_credentials, google_secret_manager_secret_version.trilium_backup_credentials, google_service_account_key.trilium_backup (+5 more)

### Community 55 - "backup-trilium.py"
Cohesion: 0.35
Nodes (11): OSError, add_file(), check_database(), checksum(), main(), make_archive(), Path, TarFile (+3 more)

### Community 56 - "restore-trilium.py"
Cohesion: 0.42
Nodes (9): TarInfo, archive_members(), check_database(), empty_destination(), main(), Path, TarFile, Download and safely restore a Trilium backup into an empty isolated directory. (+1 more)

## Knowledge Gaps
- **86 isolated node(s):** `build-image.sh script`, `provider.registry.opentofu.org/dmacvicar/libvirt`, `provider.registry.opentofu.org/hashicorp/local`, `provider.registry.opentofu.org/kreuzwerker/docker`, `provider.docker` (+81 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 148 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `var.project_id` connect `var.project_id` to `google_secret_manager_secret.keycloak_db_credentials`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **Why does `OIDCError` connect `kubectl-keycloak-login.py` to `RuntimeError`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **Why does `kubernetes_manifest.keycloak_certificate` connect `pki.tf` to `keycloak.tf`?**
  _High betweenness centrality (0.004) - this node is a cross-community bridge._
- **Are the 10 inferred relationships involving `RuntimeError` (e.g. with `_json_object()` and `main()`) actually correct?**
  _`RuntimeError` has 10 INFERRED edges - model-reasoned connections that need verification._
- **What connects `build-image.sh script`, `provider.registry.opentofu.org/dmacvicar/libvirt`, `provider.registry.opentofu.org/hashicorp/local` to the rest of the system?**
  _86 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `03-compute/variables.tf` be split into smaller, more focused modules?**
  _Cohesion score 0.12666666666666668 - nodes in this community are weakly interconnected._
- **Should `var.project_id` be split into smaller, more focused modules?**
  _Cohesion score 0.12375533428165007 - nodes in this community are weakly interconnected._