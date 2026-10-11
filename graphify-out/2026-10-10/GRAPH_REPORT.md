# Graph Report - llm-studio  (2026-10-08)

## Corpus Check
- 58 files · ~153,030 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 7 file(s) not represented in the graph (top: (none) 3, .tftpl 2, .cfg 1)

## Summary
- 328 nodes · 496 edges · 44 communities (21 shown, 11 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 5 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `bd8f32d4`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- pki.tf
- mail-server.tf
- keycloak.tf
- 02-dns/main.tf
- kubernetes_manifest.gcp_secret_store
- 05-gcp/secrets.tf
- 04-platform/.terraform.lock.hcl
- 02-dns/.terraform.lock.hcl
- 05-gcp/.terraform.lock.hcl
- 05-gcp/infisical.tf
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
- configure-keycloak-google-idp.py
- provider.libvirt
- fetch-mail-coreos.py

## God Nodes (most connected - your core abstractions)
1. `What You Must Do When Invoked` - 12 edges
2. `local.mail_guest_files` - 11 edges
3. `main()` - 11 edges
4. `var.project_id` - 10 edges
5. `OIDCError` - 10 edges
6. `/graphify` - 10 edges
7. `google_secret_manager_secret_version.infisical_bootstrap` - 9 edges
8. `_browser_login()` - 9 edges
9. `merge_kubeconfig()` - 9 edges
10. `var.pool_name` - 8 edges

## Surprising Connections (you probably didn't know these)
- `docker_container.adguardhome` --references--> `var.host_lan_ip`  [EXTRACTED]
  terraform/layers/02-dns/main.tf → terraform/layers/02-dns/variables.tf
- `libvirt_volume.k8s_node` --references--> `var.disk_size`  [EXTRACTED]
  terraform/layers/03-compute/main.tf → terraform/layers/03-compute/variables.tf
- `libvirt_cloudinit_disk.k8s_cloudinit` --references--> `var.k8s_api_hostname`  [EXTRACTED]
  terraform/layers/03-compute/main.tf → terraform/layers/03-compute/variables.tf
- `libvirt_domain.k8s_node` --references--> `var.node_name`  [EXTRACTED]
  terraform/layers/03-compute/main.tf → terraform/layers/03-compute/variables.tf
- `output.k8s_node_ip` --references--> `libvirt_domain.k8s_node`  [EXTRACTED]
  terraform/layers/03-compute/outputs.tf → terraform/layers/03-compute/main.tf

## Import Cycles
- None detected.

## Communities (44 total, 11 thin omitted)

### Community 0 - "pki.tf"
Cohesion: 0.14
Nodes (21): data.google_secret_manager_secret.private_ca, data.google_secret_manager_secret_version.private_ca, helm_release.cert_manager, helm_release.traefik, kubernetes_manifest.cert_manager, kubernetes_manifest.infisical, kubernetes_manifest.infisical_certificate, kubernetes_manifest.keycloak_certificate (+13 more)

### Community 1 - "mail-server.tf"
Cohesion: 0.09
Nodes (41): data.google_secret_manager_secret_version.mail_ca, data.terraform_remote_state.gcp, libvirt_cloudinit_disk.k8s_cloudinit, libvirt_domain.k8s_node, libvirt_domain.mail_server, libvirt_ignition.mail_server, libvirt_volume.k8s_node, libvirt_volume.mail_base (+33 more)

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

### Community 9 - "05-gcp/infisical.tf"
Cohesion: 0.14
Nodes (29): data.google_project.current, google_kms_crypto_key_iam_member.gcs_service_agent, google_kms_crypto_key_iam_member.infisical_backup_encrypter, google_kms_crypto_key_iam_member.mail_backup_gcs_service_agent, google_kms_crypto_key.infisical_backups, google_kms_crypto_key.mail_backups, google_kms_key_ring.infisical_backups, google_kms_key_ring.mail_backups (+21 more)

### Community 12 - "03-compute/.terraform.lock.hcl"
Cohesion: 0.40
Nodes (4): provider.registry.opentofu.org/dmacvicar/libvirt, provider.registry.opentofu.org/hashicorp/google, provider.registry.opentofu.org/hashicorp/random, provider.registry.opentofu.org/hashicorp/tls

### Community 27 - "What You Must Do When Invoked"
Cohesion: 0.08
Nodes (24): For /graphify add and --watch, For /graphify query, For the commit hook and native CLAUDE.md integration, For --update and --cluster-only, /graphify, Honesty Rules, Interpreter guard for subcommands, Part A - Structural extraction for code files (+16 more)

### Community 28 - "graphify reference: extra exports and benchmark"
Cohesion: 0.22
Nodes (8): graphify reference: extra exports and benchmark, Step 6b - Wiki (only if --wiki flag), Step 7 - Neo4j export (only if --neo4j or --neo4j-push flag), Step 7a - FalkorDB export (only if --falkordb or --falkordb-push flag), Step 7b - SVG export (only if --svg flag), Step 7c - GraphML export (only if --graphml flag), Step 7d - MCP server (only if --mcp flag), Step 8 - Token reduction benchmark (only if total_words > 5000)

### Community 29 - "Terraform layers"
Cohesion: 0.14
Nodes (13): Deploy AdGuard DNS, Deploy Headlamp, GitOps role and user workflow, Homelab, Infisical recovery and bootstrap, Keycloak bootstrap and OIDC provisioning, Local mail server, Manual Google sign-in runbook (+5 more)

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

### Community 41 - "configure-keycloak-google-idp.py"
Cohesion: 0.35
Nodes (11): RuntimeError, _json_object(), main(), _parser(), Any, ArgumentParser, SSLContext, Create or update the Platform realm Google identity provider. Credentials are… (+3 more)

### Community 42 - "provider.libvirt"
Cohesion: 0.50
Nodes (3): provider.google, provider.libvirt, var.libvirt_uri

## Knowledge Gaps
- **79 isolated node(s):** `build-image.sh script`, `provider.registry.opentofu.org/dmacvicar/libvirt`, `provider.registry.opentofu.org/hashicorp/local`, `provider.registry.opentofu.org/kreuzwerker/docker`, `provider.docker` (+74 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 120 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `kubernetes_manifest.keycloak_certificate` connect `pki.tf` to `keycloak.tf`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Why does `OIDCError` connect `kubectl-keycloak-login.py` to `configure-keycloak-google-idp.py`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **Why does `var.gcp_project_id` connect `kubernetes_manifest.gcp_secret_store` to `pki.tf`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **What connects `build-image.sh script`, `provider.registry.opentofu.org/dmacvicar/libvirt`, `provider.registry.opentofu.org/hashicorp/local` to the rest of the system?**
  _79 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `pki.tf` be split into smaller, more focused modules?**
  _Cohesion score 0.14461538461538462 - nodes in this community are weakly interconnected._
- **Should `mail-server.tf` be split into smaller, more focused modules?**
  _Cohesion score 0.09082125603864734 - nodes in this community are weakly interconnected._
- **Should `05-gcp/infisical.tf` be split into smaller, more focused modules?**
  _Cohesion score 0.13911290322580644 - nodes in this community are weakly interconnected._