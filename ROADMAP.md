# GraphEssentials roadmap

The features below are planned, not available configuration options. No release date is assigned.

## Azure Key Vault-backed certificate sessions

- [ ] Add an optional durable credential/state provider for certificate sessions running on fresh Azure DevOps agents, while preserving the current Windows DPAPI provider and disabled defaults.
- [ ] Define vault authentication and least-privilege access separately from the application's Graph permissions.
- [ ] Choose how the provider supplies certificate credentials: retrievable/exportable material and remote signing have different SDK and key-policy requirements.
- [ ] Persist active, pending and previous credential references and progress; select the verified active version rather than blindly using the newest vault entry.
- [ ] Define concurrency control and interrupted-write reconciliation before enabling mutations from multiple jobs.
- [ ] Add configuration/schema, safe diagnostics, previews and end-to-end fresh-agent rollover/recovery coverage.

The provider API, Azure SDK dependencies and vault deployment model remain design decisions. This roadmap does not add a Key Vault configuration field or change authentication today. Client-secret rotation is a separate capability with its own permissions, storage and consumer-update requirements.

For currently supported hosts and setup, see the [certificate-session hosting guide](Docs/CertificateRotationHosting.md).