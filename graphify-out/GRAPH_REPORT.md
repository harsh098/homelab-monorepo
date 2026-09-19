# Graph Report - llm-studio  (2026-09-19)

## Corpus Check
- 54 files · ~150,765 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 7 file(s) not represented in the graph (top: (none) 3, .tftpl 2, .cfg 1)

## Summary
- 275 nodes · 383 edges · 42 communities (19 shown, 11 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 7 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `9a4a83b8`
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
- initialize-openbao.py
- provider.registry.opentofu.org/dmacvicar/libvirt
- provider.docker
- provider.registry.opentofu.org/dmacvicar/libvirt
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

## God Nodes (most connected - your core abstractions)
1. `What You Must Do When Invoked` - 12 edges
2. `main()` - 11 edges
3. `OIDCError` - 10 edges
4. `/graphify` - 10 edges
5. `_browser_login()` - 9 edges
6. `merge_kubeconfig()` - 9 edges
7. `run()` - 8 edges
8. `main()` - 8 edges
9. `graphify reference: extra exports and benchmark` - 8 edges
10. `docker_container.adguardhome` - 7 edges

## Surprising Connections (you probably didn't know these)
- `docker_container.adguardhome` --references--> `var.host_lan_ip`  [EXTRACTED]
  terraform/layers/02-dns/main.tf → terraform/layers/02-dns/variables.tf
- `libvirt_volume.k8s_node` --references--> `var.disk_size`  [EXTRACTED]
  terraform/layers/03-compute/main.tf → terraform/layers/03-compute/variables.tf
- `libvirt_cloudinit_disk.k8s_cloudinit` --references--> `var.k8s_api_hostname`  [EXTRACTED]
  terraform/layers/03-compute/main.tf → terraform/layers/03-compute/variables.tf
- `libvirt_cloudinit_disk.k8s_cloudinit` --references--> `var.ssh_public_key_path`  [EXTRACTED]
  terraform/layers/03-compute/main.tf → terraform/layers/03-compute/variables.tf
- `libvirt_domain.k8s_node` --references--> `var.network_name`  [EXTRACTED]
  terraform/layers/03-compute/main.tf → terraform/layers/03-compute/variables.tf

## Import Cycles
- None detected.

## Communities (42 total, 11 thin omitted)

### Community 0 - "pki.tf"
Cohesion: 0.16
Nodes (19): data.google_secret_manager_secret.private_ca, data.google_secret_manager_secret_version.private_ca, helm_release.cert_manager, helm_release.openbao, helm_release.traefik, kubernetes_manifest.cert_manager, kubernetes_manifest.keycloak_certificate, kubernetes_manifest.openbao_certificate (+11 more)

### Community 1 - "03-compute/variables.tf"
Cohesion: 0.16
Nodes (17): libvirt_cloudinit_disk.k8s_cloudinit, libvirt_domain.k8s_node, libvirt_volume.k8s_node, libvirt_volume.ubuntu_base, output.k8s_node_ip, output.k8s_node_mac, output.kubeconfig_path, provider.libvirt (+9 more)

### Community 2 - "keycloak.tf"
Cohesion: 0.29
Nodes (10): google_secret_manager_secret.keycloak_admin_recovery, google_secret_manager_secret_version.keycloak_admin_recovery_initial, kubernetes_manifest.keycloak, kubernetes_secret_v1.keycloak_admin, local.keycloak_admin_recovery_bundle, local.keycloak_admin_username, output.keycloak_admin_recovery_secret_name, output.keycloak_admin_recovery_secret_version (+2 more)

### Community 3 - "02-dns/main.tf"
Cohesion: 0.24
Nodes (15): docker_container.adguardhome, docker_image.adguard, local.config_dir, local.config_file, local.default_dns_records, local.dns_records, local_file.adguard_config, local.managed_data_dir (+7 more)

### Community 4 - "kubernetes_manifest.gcp_secret_store"
Cohesion: 0.31
Nodes (7): helm_release.external_secrets, kubernetes_manifest.external_secrets, kubernetes_manifest.gcp_secret_store, provider.google, provider.helm, provider.kubernetes, var.gcp_project_id

### Community 5 - "05-gcp/secrets.tf"
Cohesion: 0.19
Nodes (11): google_secret_manager_secret.backup_credentials, google_secret_manager_secret.backup_encryption_key, google_secret_manager_secret_iam_member.openbao_unseal_key_reader, google_secret_manager_secret.keycloak_google_oauth, google_secret_manager_secret.openbao_root_token, google_secret_manager_secret.openbao_unseal_key, google_secret_manager_secret_version.backup_encryption_key_version, random_password.backup_key (+3 more)

### Community 6 - "04-platform/.terraform.lock.hcl"
Cohesion: 0.40
Nodes (4): provider.registry.opentofu.org/hashicorp/google, provider.registry.opentofu.org/hashicorp/helm, provider.registry.opentofu.org/hashicorp/kubernetes, provider.registry.opentofu.org/hashicorp/random

### Community 9 - "initialize-openbao.py"
Cohesion: 0.36
Nodes (11): CompletedProcess, add_gcp_version(), apply_bootstrap_secret(), bao(), gcp_secret(), main(), parser(), ArgumentParser (+3 more)

### Community 27 - "What You Must Do When Invoked"
Cohesion: 0.08
Nodes (24): For /graphify add and --watch, For /graphify query, For the commit hook and native CLAUDE.md integration, For --update and --cluster-only, /graphify, Honesty Rules, Interpreter guard for subcommands, Part A - Structural extraction for code files (+16 more)

### Community 28 - "graphify reference: extra exports and benchmark"
Cohesion: 0.22
Nodes (8): graphify reference: extra exports and benchmark, Step 6b - Wiki (only if --wiki flag), Step 7 - Neo4j export (only if --neo4j or --neo4j-push flag), Step 7a - FalkorDB export (only if --falkordb or --falkordb-push flag), Step 7b - SVG export (only if --svg flag), Step 7c - GraphML export (only if --graphml flag), Step 7d - MCP server (only if --mcp flag), Step 8 - Token reduction benchmark (only if total_words > 5000)

### Community 29 - "Terraform layers"
Cohesion: 0.17
Nodes (11): Deploy AdGuard DNS, Deploy Headlamp, GitOps role and user workflow, Homelab, Keycloak bootstrap and OIDC provisioning, Manual Google sign-in runbook, Power outage recovery, Prerequisites (+3 more)

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

## Knowledge Gaps
- **75 isolated node(s):** `build-image.sh script`, `provider.registry.opentofu.org/dmacvicar/libvirt`, `provider.registry.opentofu.org/hashicorp/local`, `provider.registry.opentofu.org/kreuzwerker/docker`, `provider.docker` (+70 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 119 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **11 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `OIDCError` connect `kubectl-keycloak-login.py` to `configure-keycloak-google-idp.py`?**
  _High betweenness centrality (0.018) - this node is a cross-community bridge._
- **Why does `kubernetes_manifest.keycloak_certificate` connect `pki.tf` to `keycloak.tf`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Why does `var.gcp_project_id` connect `kubernetes_manifest.gcp_secret_store` to `pki.tf`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **What connects `build-image.sh script`, `provider.registry.opentofu.org/dmacvicar/libvirt`, `provider.registry.opentofu.org/hashicorp/local` to the rest of the system?**
  _75 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `What You Must Do When Invoked` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._