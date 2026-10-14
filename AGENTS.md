# Terraform — conventions for AI agents

This file tells an AI coding agent how to write, change and verify Terraform code in this repository. It is organised in three layers so it can be reused elsewhere:

- **Part 0** — how the agent works (what it may do, what it must never do). Always keep.
- **Part 1** — Terraform rules, provider-agnostic. Always keep.
- **Part 2** — AWS rules. Delete it if this repo does not target AWS; copy its structure to add another provider (a skeleton for that is at the end).
- **Part 3** — repository-specific values. Fill it in: an agent follows a written convention and invents a missing one.

Rules use MUST / NEVER / PREFER. MUST and NEVER are not negotiable. PREFER is the default, and deviating from it requires a one-line justification in the code or the PR.

## Scope: child module or root module

This repository is a **child module** (a reusable module called by other code): it declares `required_providers` but no `provider` block, no backend and no `.terraform.lock.hcl`. Root modules (the code that owns a state and is applied) only appear in `examples/`, or in the repositories that call this module.

Rules that apply to only one kind of module carry a tag: **[child]** or **[root]**. A rule without a tag applies to both. In this repository, follow the untagged and **[child]** rules; read the **[root]** rules when you touch an example or when this file is reused in a root-module repository.

---

## Part 0 — How the agent works here

### The deliverable is the plan, not the code

Terraform code that "looks right" is not the goal. A `terraform plan` that does exactly what was asked, and nothing else, is. Every change you make ends with you reading the plan and reporting what it will create, update, replace or destroy. If you cannot run a plan (no credentials, no backend access), say so explicitly rather than asserting the code is correct.

### Commands you propose, a human runs

- NEVER run `terraform apply`, `terraform destroy`, `terraform state rm|mv|push`, `terraform import`, `terraform workspace delete`, or `terraform force-unlock`. Produce the command and the reasoning; a human executes it after reading the plan.
- You MAY run `terraform fmt`, `terraform init` (with `-backend=false` when no backend access is intended), `terraform validate`, `terraform plan`, `terraform test`, `terraform show`, `terraform providers`, `tflint`, `trivy config`, `terraform-docs`.
- A plan containing `destroy` or `replace` (`-/+`) MUST be flagged in your summary, line by line, before anything else. Do not bury it.

### Verification loop, every time

After every edit, before reporting done, run in order and fix what fails:

1. `terraform fmt -recursive`
2. `terraform validate`
3. `tflint` (with the provider ruleset enabled)
4. `trivy config .` (or the scanner configured in this repo)
5. `terraform test` if tests exist
6. `terraform plan` if you have access

A green scanner after your changes is a weaker signal than a green scanner on hand-written code. When you fix a security finding, state what the effective permissions or exposure are before and after. Restructuring a policy until the scanner is quiet is not a fix.

### Things you must never do to "make it pass"

- NEVER delete or comment out a resource, a `validation`, a `precondition`, a `check`, or a test to make a plan or a test succeed. Report the conflict instead.
- NEVER widen an IAM permission, a firewall rule or a network range to unblock yourself.
- NEVER add `lifecycle { ignore_changes = all }` or a broad `ignore_changes` as a workaround.
- NEVER invent a resource type, argument or attribute. If you are unsure whether it exists in the pinned provider version, look it up (see MCP below); if you cannot, say so.
- NEVER change a pinned version (Terraform, provider, module) as a side effect of another task. Version bumps are their own change, with the changelog read and summarised.

### Context and freshness

- Terraform and provider syntax changes faster than training data. For any provider resource you touch, check the documentation for the version pinned in this repo via the Terraform MCP server (`terraform-mcp-server`) before writing code. At the start of a session, confirm the MCP server responds; if it does not, say so and treat generated provider arguments as unverified.
- Read `.terraform.lock.hcl`, `versions.tf` and this file before proposing anything.
- The agent sees the code, not the state or the target account. Anything that depends on state (`import`, `moved`, `removed`, drift, what a `destroy` will actually remove) needs a human with access. Say what you cannot see.

### Secrets and sensitive data

- NEVER read, print, or paste into your own context: `*.tfstate`, `*.tfstate.backup`, `*.tfvars` containing credentials, `.env`, private keys, tokens. If a task requires them, ask the human to extract the non-sensitive part.
- NEVER put the real value of a secret in code. Use variables marked `sensitive`, ephemeral resources or write-only arguments (Part 1). Only when none of these is possible, a placeholder is tolerated if it is obviously fake (e.g. `"CHANGE_ME"`, never something that looks like a real credential), commented as such, and the real value is set out of band afterwards (secret manager console, pipeline).

### Scope discipline

- Do what was asked. Do not refactor, rename, "clean up" or reformat unrelated code in the same change. Suggest it separately.
- When a request is ambiguous about something irreversible (a resource replacement, a state move, a CIDR change), ask before writing code.

---

## Part 1 — Terraform, provider-agnostic

### Versions and pinning

- `versions.tf` at the root of every root module and every child module MUST declare `required_version` and `required_providers` with `source` and `version`.
- **[child]** Terraform binary: `required_version = ">= X.Y, < 2.0"` with X.Y being the minimum the code needs (see Part 3). The range tells callers which context the module was written for. Do not use `~>` in a child module: it is too narrow for a module that many callers combine with their own constraints.
- **[child]** Providers: same shape, `version = ">= 6.0, < 7.0"` with the minimum the code needs. No `~>`: the lock file belongs to the root module, not to the child.
- **[root]** Terraform binary: `~> 1.0` is acceptable, because the binary usually comes from a Docker image or a tool-version manager with its own lifecycle; it avoids editing every `versions.tf` on each Terraform upgrade. Use a tighter constraint when the code needs a minimum minor version.
- **[root]** Providers: pessimistic constraint on the major, e.g. `version = "~> 6.0"`. The lock file guarantees the same provider versions between two pipelines. Same value across every root module of the repo.
- Modules from a registry: exact version in root modules (`version = "3.18.1"`, no `v` prefix), preferably the latest release compatible with the pinned provider. In a child module, prefer a range (`>= 3.18, < 4.0`) for the same reason as providers.
- Modules from git: PREFER a commit SHA in `?ref=` over a tag, because a tag is mutable: it can be moved or re-pushed, so the same `ref` can silently deliver different code (supply-chain risk), while a SHA always points to the same content. Add the tag as a trailing comment for readability (`?ref=<sha> # v1.2.3`). A specific tag is accepted when the team chooses it (readability, no tooling to keep SHAs up to date); never a branch. A dependency bot (e.g. Renovate) can maintain the SHA and its tag comment.
- **[root]** `.terraform.lock.hcl` MUST be committed. Regenerate it with `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 ...` for every platform used (developer machines and CI). **[child]** The module itself has no lock file to commit; the callers' root modules own it.
- OpenTofu: if the repo uses OpenTofu, say so in Part 3. Most rules here apply; state encryption and early variable evaluation are OpenTofu-only, `ephemeral` and write-only arguments have diverging support. Do not mix `terraform` and `tofu` commands in one repo.

### Repository layout

This repository is a child module with the standard layout:

```
main.tf  variables.tf  outputs.tf  locals.tf  datasources.tf  versions.tf   module code
examples/<case>/                                                           runnable root modules using this module
tests/                                                                     .tftest.hcl files (to create)
docs/  scripts/                                                            documentation, helper scripts
CHANGELOG.md  MIGRATIONS.md  CONTRIBUTING.md  README.md                    module documentation
```

If this file is reused in another repository, replace this block with that repository's layout.

### Files and formatting

- `terraform fmt` is mandatory; the CI fails on `fmt -check`.
- Standard file names, for root and child modules: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `locals.tf`, `data.tf` when data sources are numerous. Split `main.tf` by concern (`network.tf`, `iam.tf`) when it exceeds a few hundred lines.
- **[root]** `providers.tf` (provider configuration) and the backend block. A child module has neither.
- Resource names: `snake_case`, no repetition of the type (`resource "aws_s3_bucket" "logs"`, not `"logs_bucket"`). Use `this` for the single main resource of a module.
- `.gitignore` MUST exclude `.terraform/`, `*.tfstate*`, `*.tfvars`, `crash.log`, `*.plan`. Example root modules in `examples/` may ship a reviewed, non-sensitive `*.tfvars` or `*.auto.tfvars`: add an explicit negation rule for those files (e.g. `!examples/**/example.auto.tfvars`) rather than loosening the global rule.
- Comments explain *why*, not *what*. Any deliberate deviation from these conventions (a wide permission in a sandbox, a `count` where `for_each` was expected) gets a comment starting with `# DELIBERATE:` and the reason.

### Modules

- A module does one thing and exposes a small, stable interface. Do not write a module that wraps a single resource without adding logic, validation or conventions.
- PREFER local modules by relative path (`source = "../../modules/vpc"`) inside the repo; registry or git sources with pinned versions for shared modules.
- **[child]** Modules MUST NOT declare `provider` blocks. They declare `required_providers` (and `configuration_aliases` when they need several configurations) and receive providers from the caller (`providers = { aws = aws.other_account }`).
- Every module ships with: `README.md` (generated by `terraform-docs`, with a usage example), `examples/<case>/` runnable as-is, `tests/` (see Testing), `CONTRIBUTING.md` (contribution guidelines), and, if published, a `CHANGELOG.md` plus a `MIGRATIONS.md` that explains to users how to upgrade across breaking changes.
- No `output` of a value that is trivially derivable by the caller; every output that a caller needs to chain modules (IDs, ARNs, names). Outputs that carry secrets are marked `sensitive = true`, and the README says so — they still land in the state.
- Before extracting existing resources into a module, generate `moved` blocks so the plan is empty. An empty plan is the acceptance criterion of a refactoring.

### Variables, locals, outputs

- Every variable has `type` (strict: `object({...})` over `map(any)`), `description`, and a `default` only if a sensible one exists. No `type = any`.
- Booleans that switch a feature are named `enable_<feature>` or `create_<thing>`.
- Use `validation` blocks for every constraint the provider will not enforce early: naming patterns, allowed values, CIDR shape, length limits. Error messages state the rule and the received value. Cross-variable validation (referencing other variables or resources) is available since Terraform 1.9.
- `nullable = false` on variables that must not be null. `sensitive = true` on secrets.
- Locals for repeated expressions, computed names and tag maps. Not for constants that should be variables, not as a dumping ground.
- Outputs have a `description`. **[child]** Outputs are the module's contract with its callers: renaming or removing one is a breaking change (document it in `MIGRATIONS.md`). **[root]** Outputs are the contract read by other states (see State).

### Meta-arguments: `for_each`, `count`, `depends_on`, `lifecycle`

- PREFER `for_each` over `count` whenever there is more than one instance. `count` re-indexes and destroys resources when the list shifts; `for_each` keyed on a stable string does not.
- `count = var.create ? 1 : 0` is the accepted idiom for an optional single resource. That is the *only* use of `count`. (A "conditional resource" is a `count` of 0 or 1 — there is no separate mechanism.) Reference it as `resource.name[0]` and expose it through `one(resource.name[*].id)` in outputs.
- Never `for_each` on a set of values that are not known at plan time (computed IDs); key on names or input keys instead.
- `depends_on` is a last resort for hidden dependencies (IAM propagation, eventual consistency). Prefer implicit dependencies through attribute references. Comment every `depends_on`.
- `lifecycle`:
  - `prevent_destroy = true` on stateful resources (databases, buckets holding data, KMS keys, DNS zones).
  - `create_before_destroy = true` on resources whose replacement must not cause downtime (launch templates, certificates, security groups referenced elsewhere).
  - `ignore_changes` only on specific attributes that are legitimately managed elsewhere (autoscaling `desired_capacity`, image tags pushed by a deploy pipeline), each with a comment. Never `all`.
  - `precondition` / `postcondition` to encode assumptions about inputs and results (Terraform 1.2+), `check` blocks for assertions that must not block the apply (1.5+).

### State

A child module has no state of its own: the rules below apply to the root modules that call it, including the ones in `examples/`.

- **[root]** Remote backend MUST be used for anything beyond a throwaway experiment; the backend storage MUST be versioned, encrypted at rest, private, and support locking. Provider-specific configuration is in Part 2.
- **[root]** One state per root module. Never share a state between environments.
- State manipulation (`state mv|rm|push`, `import`, `force-unlock`) is human-only, after a backup (`terraform state pull > backup.tfstate` — the human does this, not you).
- PREFER `moved`, `removed` and `import` *blocks* in code (Terraform 1.1 / 1.7 / 1.5) over the CLI equivalents: they are reviewable in a PR and replayable. `import` blocks are supported inside modules since Terraform 1.16. Use `terraform plan -generate-config-out=` to bootstrap configuration of imported resources, then clean the generated code.
- **[root]** Reading another state: a data source on the real resource or a parameter/secret store decouples the states from each other; `terraform_remote_state` is acceptable when it makes obvious which project owns the resource. Whichever you choose, the plan fails when the target is renamed or removed. **[child]** A child module does not read remote state: it receives what it needs through variables.
- **[root]** Drift: the state is not the truth, the platform is. When asked about "what exists", say that only a `plan` (or `terraform query` / `list` blocks, Terraform 1.14+) against the account can answer.

### Secrets

- Anything Terraform reads or writes ends up in the state in clear text, including values marked `sensitive` (that flag only masks CLI output). Design on that assumption.
- PREFER, in this order:
  1. Not having Terraform touch the secret at all (the application fetches it at runtime from a secret manager Terraform only *references*).
  2. Ephemeral resources (Terraform 1.10+) and write-only arguments (`*_wo`, Terraform 1.11+, provider support required): the value is sent to the provider and never persisted. For values that must survive plan-to-apply, `terraform_data` with a `store` block (Terraform 1.16+).
  3. `random_password` + `sensitive` + encrypted state, as a fallback, documented as such.
- Never a secret in a `default`, in a committed `.tfvars`, in an `output` without `sensitive`, or in a `local`.
- Rotation MUST be possible without a `destroy`: use `*_version` resources or keepers on `random_*` resources.

### Naming and tagging (generic)

- One naming convention for the whole repo, defined once in Part 3 and applied through a `local.name_prefix`. Typical shape: `<org>-<project>-<env>-<component>`, lowercase, hyphens. Respect per-service length and character limits (validate them).
- Names unique within a shared namespace (global or account-wide: buckets, IAM roles, DNS) get a unique suffix (`random_id` or account/region) so several deployments can coexist, unless the provider offers a namespace reserved to your account (see S3 in Part 2). Never a hard-coded global name.
- Tags/labels are applied at provider level when the provider supports defaults, and merged with resource-specific tags otherwise. Minimum set, keys in Part 3: `environment`, `owner`, `project`, `cost_center`, `managed_by = "terraform"`, `root_module` (URL of the repository and path of the root module whose `apply` manages the resource). Add `data_classification` when the resource stores data.

### Testing and quality gates

- `terraform test` (Terraform 1.6+) is the default framework. `.tftest.hcl` files live in `tests/` next to the module. Use `command = plan` for logic and validation tests (fast, no credentials), `command = apply` for a small number of integration tests run in CI against a sandbox, with teardown guaranteed. As a safety net for resources leaked by failed tests, run a scheduled cleanup on the sandbox account (e.g. `aws-nuke`), restricted to that account.
- Tests describe the *expected behaviour from the requirement*, not what the current code does. A test derived from reading the code is tautological. Before considering a test useful, break the code deliberately (remove the encryption block, change a default) and check that the test fails. If it does not, the test is worthless — rewrite it.
- Every `validation` block has at least one test with `expect_failures` for the rejected case and one passing case at the boundary. Every `precondition`/`postcondition` has a failing test.
- Every module has at least one runnable example under `examples/` and a test that plans it.
- Static analysis is mandatory in pre-commit and CI: `terraform fmt -check`, `validate`, `tflint` with the provider ruleset, `trivy config` (tfsec is discontinued and merged into Trivy; use `#trivy:ignore:<rule>` comments with a justification, never `#tfsec:ignore`), optionally `checkov`. Suppressions are commented, scoped to one resource, and reviewed.
- Cost estimation (`infracost` or equivalent) in the PR pipeline for anything that changes compute, storage or data transfer.

### CI/CD and workflow

For a child module, the pipeline stops at `fmt/validate/lint/scan` and `test` (plus a release). The `plan` and `apply` stages below belong to the root modules that call it.

- Pipeline stages: `fmt/validate/lint/scan` → `test` → `plan` (artifact saved, posted on the merge request) → manual approval → `apply` of *that saved plan file* (`terraform apply plan.out`), never a fresh plan at apply time.
- Production is applied only from the pipeline, from the default branch, with an identity that is short-lived (OIDC federation) and scoped to that root module. No long-lived cloud credentials in CI variables.
- Every root module gets a scheduled `plan` (drift detection) that alerts on a non-empty plan.
- `terraform init -upgrade` and lock file updates are separate, reviewed commits.
- Local developer identities are read-only by default; write access is elevated on purpose, for a session.

### Documentation

- `terraform-docs` generates the inputs/outputs/providers tables of every module README; the generated block is delimited and never hand-edited. Configure it with a `.terraform-docs.yml` file at the repository root so the output is the same locally and in pre-commit.
- **[root]** The root `README.md` of the repository explains: how to authenticate, how to bootstrap the backend, deployment order between root modules, how to run tests, and how to tear down. **[child]** The `README.md` explains what the module does, its inputs and outputs, how to call it and how to run its tests.
- Architecture decisions that constrain the code (why two VPCs, why this region) live in short ADRs, linked from the README.

### Cost and sustainability

Infrastructure as code decides the footprint for years; the cheapest and greenest resource is the one not created.

- Default to the smallest instance/tier that meets the stated requirement; scale-up is a variable, not a default. Do not "future-proof" sizes.
- Every non-production environment has a schedule (stop outside working hours) or a TTL, and `terraform destroy` works cleanly on it (no orphaned resources, no `prevent_destroy` outside prod, buckets emptied by `force_destroy = true` in non-prod only).
- PREFER managed, serverless or autoscaled services with scale-to-zero when the workload allows; PREFER ARM instances when the software supports them; PREFER regions with a low carbon intensity when latency and data residency allow (this is a Part 3 decision, not a per-resource one).
- Lifecycle rules on every storage bucket (transition, expiration, abort incomplete multipart uploads). Log retention is finite and explicit.
- When you propose a resource, mention its recurring cost order of magnitude if it is not negligible (NAT gateways, load balancers, managed databases, KMS keys, VPC endpoints).

---

## Part 2 — AWS

Delete this part if the repository does not target AWS. Keep Part 1 either way.

### Provider and authentication

- **[child]** `required_providers { aws = { source = "hashicorp/aws", version = ">= 6.0, < 7.0" } }` (verify the current major before starting a new repo).
- **[root]** `required_providers { aws = { source = "hashicorp/aws", version = "~> 6.0" } }`, same constraint across the repo.
- **[root]** Authentication through named profiles locally and OIDC role assumption in CI. NEVER `access_key` / `secret_key` arguments in a provider block, NEVER credentials in `.tfvars`.
- **[root]** `default_tags` in the provider block carries the common tag set (Part 1); resource-level `tags` only add specific keys. Beware of resources that do not support `default_tags` (some `aws_autoscaling_group` tag semantics, resources tagged by other services). **[child]** The module exposes a `tags` variable and merges it into its resources.
- Provider aliases: the most common case is assuming a different IAM role to target another account, or another perimeter within the same account. **[child]** Declare them with `configuration_aliases` and let the caller pass them. **[root]** Define them in `providers.tf` with `assume_role`.
- Multi-region: since provider v6, most resources accept a `region` argument; prefer it over multiplying provider aliases when the resource supports it. Keep aliases for cases the argument does not cover (cross-region replication configuration, some global services).
- **[root]** Multi-account: one root module per account/role; `assume_role` in the provider with a session name that identifies the pipeline or the human.

### Backend

**[root]** only: a child module has no backend.

```hcl
terraform {
  backend "s3" {
    bucket       = "<org>-tfstate-<account-id>-<region>"
    key          = "<component>/<env>/terraform.tfstate"
    region       = "<region>"
    encrypt      = true
    # kms_key_id = "<kms key arn>"      # optional: SSE-KMS instead of the default SSE-S3 (see below)
    use_lockfile = true                 # native S3 locking, Terraform >= 1.10
  }
}
```

- `use_lockfile = true` replaces the DynamoDB lock table (`dynamodb_table` is deprecated). Do not create a DynamoDB table for locking in new code; remove it from existing code only as its own migration, after confirming every consumer of that state runs Terraform >= 1.10.
- The state bucket: versioning on, public access blocked, SSE-S3 by default (simpler to operate, no KMS key policy to maintain; access to the states is controlled by the bucket policy, with explicit `Deny` statements for everyone but the deploy roles). Use SSE-KMS with a customer-managed key when compliance requires it or when you need to control access to the key separately from the bucket. Also: lifecycle rule to expire old versions after a defined period, bucket policy restricting access to the deploy roles, access logging to a separate bucket. It is bootstrapped once (by a dedicated tiny root module or manually, documented), never by the root module that uses it.

### IAM

- Least privilege by construction: explicit `actions`, explicit `resources` (ARNs or ARN patterns), `condition` blocks where the service supports them (`aws:SourceArn`, `aws:PrincipalOrgID`, `aws:RequestedRegion`). `"*"` on both actions and resources is forbidden outside a documented sandbox exception (`# DELIBERATE:`).
- Write policies with `data "aws_iam_policy_document"` rather than heredoc JSON: it validates structure and merges cleanly with `source_policy_documents`.
- Attach policies with `aws_iam_role_policy_attachment` or `aws_iam_role_policy`. NEVER use `aws_iam_policy_attachment`: it creates an exclusive attachment and revokes the policy from every other role, user or group that has it. The `managed_policy_arns` and `inline_policy` arguments on `aws_iam_role` are deprecated.
- Roles for humans and CI are assumed with short sessions (OIDC for GitLab/GitHub, IAM Identity Center for people). No IAM users with access keys except a documented break-glass.
- Names of IAM roles and policies are account-global: apply the unique prefix/suffix rule.
- Permission boundaries on roles created by pipelines, so a pipeline cannot create a role more powerful than itself.

### Encryption and data protection

- Encryption at rest is on for every service that supports it. PREFER the simplest mechanism that meets the requirement: SSE-S3 (or the service's AWS-owned/managed key) is the default; use a customer-managed KMS key (`aws_kms_key` + `aws_kms_alias`, `enable_key_rotation = true`) when the data classification, a compliance rule or the need to control access to the key separately requires it. A customer-managed key adds key-policy and IAM complexity: state the reason in the code.
- S3: `aws_s3_bucket_public_access_block` with all four flags true on every bucket, `aws_s3_bucket_versioning` on buckets holding data, `aws_s3_bucket_server_side_encryption_configuration` explicit, `aws_s3_bucket_lifecycle_configuration` present, bucket policy enforcing `aws:SecureTransport`. Bucket names live in a global namespace shared by all accounts of the partition: add a unique suffix. Alternative: the account regional namespace (names `<prefix>-<account-id>-<region>-an`, requested at creation with the `account-regional` bucket namespace; check that the pinned AWS provider version supports it before using it), where only your account can ever own the name and no random suffix is needed.
- RDS/Aurora: `storage_encrypted = true`, `deletion_protection = true` in prod, `backup_retention_period` explicit, `publicly_accessible = false`, master password through `manage_master_user_password = true` (Secrets Manager) or a write-only argument, never a variable stored in state.
- Secrets: PREFER SSM Parameter Store `SecureString` for configuration and plain secrets (free tier, sufficient for most cases); Secrets Manager when rotation, cross-account sharing or RDS integration is needed. Write values with write-only arguments (`secret_string_wo`, `value_wo`) on a provider version that supports them.
- EBS default encryption enabled at account level (`aws_ebs_encryption_by_default`).
- CloudTrail, Config and GuardDuty are account-level baselines managed in a dedicated security root module, not per application.

### Networking

- VPC CIDRs from RFC 1918 ranges only, planned to avoid overlap across accounts and environments (document the plan in Part 3). No `/16` by default in small environments; size subnets for real needs.
- Subnet tiers: public (load balancers, NAT), private (compute), isolated (data stores, no route to NAT). Resources go in the most private tier that works.
- NAT gateways cost money per hour and per GB: one per AZ in prod for resilience, one per VPC in non-prod, none when VPC endpoints cover the needed services. Mention this trade-off when you create one.
- VPC endpoints (gateway endpoints for S3 and DynamoDB are free; interface endpoints are not) for AWS services reached from private subnets, before considering NAT.
- Security groups: `aws_vpc_security_group_ingress_rule` / `_egress_rule` resources rather than inline `ingress`/`egress` blocks (inline blocks and standalone rules conflict). No `0.0.0.0/0` ingress except on public load balancers on 80/443, and never on SSH/RDP. Egress restricted where practical. Reference security groups by ID, not CIDR, between tiers.
- `aws_instance`: `vpc_security_group_ids`, never `security_groups` (EC2-Classic legacy). `metadata_options { http_tokens = "required" }` (IMDSv2). Root volume encrypted. AMI from `data "aws_ssm_parameter"` on the public AMI parameters (`/aws/service/ami-amazon-linux-latest/...`) or `data "aws_ami"` with `owners` and a precise `filter` — provider v6 errors on `most_recent = true` without owner/filter. Never a hard-coded AMI ID.
- Transit Gateway when there are more than a handful of VPCs or accounts to interconnect; VPC peering below that. Both are architecture decisions to confirm with a human, not defaults.
- Flow logs enabled on production VPCs, to S3 or CloudWatch with a finite retention.

### Compute, scaling, availability

- Launch templates (never launch configurations) with `create_before_destroy`. Auto Scaling Groups with `instance_refresh` for rolling updates; `ignore_changes = [desired_capacity]` when a scaling policy owns it (commented).
- Multi-AZ for anything stateful in prod (`multi_az = true` on RDS, at least two subnets on ALBs and ASGs). Single-AZ is acceptable and cheaper in non-prod, as a variable.
- ECS/EKS: task or pod IAM roles (IRSA / Pod Identity), never node-level permissions for application access. Fargate or Graviton nodes by default when the images allow.
- Lambda: `reserved_concurrent_executions` considered, log group created explicitly with retention (otherwise Lambda creates one with infinite retention), ARM64 architecture by default.

### Observability

- Every log group is created in Terraform with `retention_in_days` set. No implicit, never-expiring log groups.
- CloudWatch alarms on the golden signals of what you create (errors, latency, saturation) and an AWS Budgets alert with a threshold per account/environment. Alarm actions go to an SNS topic managed in a shared module.

### Cost specifics

- Commitment discounts (Savings Plans, Reserved Instances/Capacity) are a FinOps decision taken outside Terraform on observed usage; do not encode "reserved in prod, on-demand in dev" in the code. What Terraform *does* control: instance families (Graviton), Spot for fault-tolerant workloads (`capacity_type = "SPOT"`, mixed instances policy), S3 storage classes and lifecycle, gp3 over gp2, scheduled scaling to zero in non-prod, NAT and endpoint strategy, log retention.
- Tag `cost_center` and `environment` are non-negotiable so cost allocation reports work.

### AWS-specific pitfalls to check in generated code

- Account IDs are strings, not numbers (they may start with 0). Validate with `^[0-9]{12}$`.
- ARNs: `arn:<partition>:<service>:<region>:<account-id>:<resource>`; partition is `aws`, `aws-cn` or `aws-us-gov` — use `data.aws_partition.current.partition` in shared modules.
- IAM is eventually consistent: a role used by a resource created in the same apply may need a `depends_on` on the policy attachment (comment it).
- Some resources are region-agnostic (IAM, Route 53, CloudFront in us-east-1 for certificates) and do not accept a `region` argument: do not try to set one, use a provider alias when you need a specific region for them.
- KMS keys have a 7–30-day deletion window; deleting and recreating a key breaks everything encrypted with it. `prevent_destroy` on keys.

---

## Part 2bis — Skeleton for another provider

Copy for Scaleway, GCP, Azure, OVHcloud… and fill the same headings, so every provider part answers the same questions:

```
## Part 2 — <Provider>
### Provider and authentication     (pinning, identity, default labels/tags, multi-project/region)
### Backend                         (which object storage, locking mechanism, encryption, bootstrap)
### IAM                             (least-privilege idiom, roles vs policies, service accounts)
### Encryption and data protection  (at-rest defaults, key management, secrets service, write-only support)
### Networking                      (CIDR plan, tiers, egress strategy, private endpoints, firewall idiom)
### Compute, scaling, availability  (zonal/regional, autoscaling idiom, managed vs self-run)
### Observability                   (logs retention, alerting, budgets)
### Cost specifics                  (what the code controls, what FinOps controls)
### Provider-specific pitfalls      (types, IDs, eventual consistency, deprecated arguments)
```

---

## Part 3 — This repository (fill in)

Replace every `<...>` before first use. An agent will otherwise pick a value that looks plausible and is wrong for you. Fields marked **[root]** only matter for root modules (this repository's `examples/`, or a repository that applies Terraform).

```
Tool                : Terraform | OpenTofu          → <...>
Minimum version     : >= <1.10>  (>= 1.10 needed for use_lockfile, >= 1.11 for write-only arguments)
Providers           : aws ~> <6.0>, random ~> <3.6>, <...>
Default region(s)   : <eu-west-3>            (why: <latency / residency / carbon>)
Environments        : <dev, staging, prod>   (layout: live/<env>/<component>)
Naming prefix       : <org>-<project>-<env>-<component>
Unique suffix rule  : <random_id 4 bytes | account id | participant trigram>
Required tags       : environment, owner, project, cost_center, managed_by, root_module, <...>
CIDR plan           : <10.0.0.0/16 dev, 10.1.0.0/16 staging, 10.2.0.0/16 prod>
State backend       : <bucket name pattern>, key = <pattern>
Human-only commands : apply, destroy, state *, import, force-unlock  (+ <...>)
Scanners            : tflint (ruleset <aws>), trivy config, <checkov>, infracost
Test command        : terraform test  (run from <path>)
Deployment order    : <network → security → data → compute → app>
Teardown            : <how, and what must survive>
Owner / contact     : <team, channel>
```

### Organisation policy on AI usage (adapt or delete)

If your organisation has an AI usage policy, reference it here rather than restating it. Typical points that matter for Terraform work: which data classification the code falls under and therefore which tools are allowed on it; that secrets and state contents are never shared with any AI tool; that AI-assisted code delivered to a client is reviewed by a human and labelled as such; and that MCP servers, plugins and connectors go through a validation process before being enabled. At Ippon this is the *Charte IA* and its tool catalogue: check them before configuring an agent on client code.
