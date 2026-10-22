# Create only the KV v2 metadata entry. The operator writes api_key and email
# as the first secret version after this layer has been applied.
resource "vault_generic_endpoint" "cloudflare_metadata" {
  path                 = "platform/metadata/apps/cloudflare"
  data_json            = jsonencode({ custom_metadata = { managed_by = "terraform" } })
  ignore_absent_fields = true
  disable_delete       = true # Deleting metadata would destroy every secret version.
}
