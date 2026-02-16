# DevOps Engineer Interview Guide: Terraform & AWS Infrastructure Review

## Overview

| | |
|---|---|
| **Role** | Senior DevOps Engineer (5+ years) |
| **Duration** | 30 minutes |
| **Format** | Progressive: Triage -> Deep-Dive -> Architecture Design |
| **Scenario** | Containerized API on ECS Fargate + RDS PostgreSQL + ALB |
| **Primary signal** | Architecture thinking (Phase 3 is the pass/fail gate) |

## Framing Script

Read to the candidate at the start:

> "An AI agent generated Terraform code for a production API platform. It runs on ECS Fargate with a PostgreSQL database and an Application Load Balancer. Your team needs to review this before it goes live. We want to understand how you **think about infrastructure** -- not just whether you can spot typos. We'll walk through three phases: triage, deep-dive, and design."

---

## Phase 1: Triage & Prioritization (8 minutes)

### What to Show

All files in `terraform/` -- the root module and all three submodules:

| Module | Key file |
|--------|----------|
| Root | `terraform/main.tf`, `terraform/variables.tf` |
| Networking | `terraform/modules/networking/main.tf` |
| ECS | `terraform/modules/ecs/main.tf` |
| Database | `terraform/modules/database/main.tf` |

### Prompt

> "Here are three Terraform modules -- networking, ECS, and database -- plus the root module that wires them together. You have about 8 minutes. I do **not** want an exhaustive bug list. Instead:
>
> 1. What are your **top 3 issues** you'd block deployment over, ranked by severity?
> 2. For each, explain **why** it's dangerous -- what's the blast radius?"

### If they list line-by-line

Redirect: *"I can see you're finding a lot -- if you had to pick only three to block the deploy, which three and why?"* (Needing this redirect is itself a signal.)

### Answer Key

#### Tier 1 -- Deployment Blockers (must find at least 2 to pass this phase)

**1. RDS database is publicly accessible with an open security group**
- Files: `modules/database/main.tf` lines 21-22 and line 53
- The database SG allows port 5432 from `cidr_blocks = ["0.0.0.0/0"]`, and the RDS instance has `publicly_accessible = true`. Combined, this means anyone on the internet can attempt to connect to the production database.
- **Blast radius:** Complete database exposure. Brute-force attacks, data exfiltration, ransomware. This is the single most critical finding.
- **What a "4" answer sounds like:** "The SG should use `security_groups = [ecs_tasks_sg_id]` instead of CIDR blocks -- only the application containers should reach the database. And `publicly_accessible` must be `false`. Even if the SG were restrictive, a public RDS endpoint is a defense-in-depth failure."

**2. Database password hardcoded as a variable default**
- Files: `terraform/variables.tf` line 59 (`default = "SuperSecret123!"`), passed through `main.tf` to both the database and ECS modules, and injected as a plaintext `environment` variable in the ECS task definition (`modules/ecs/main.tf` line 166)
- **Blast radius:** The password is in version control, in Terraform state, in plan output, and visible in the ECS console's environment variables. Anyone with repo access, state access, or AWS console access can see it.
- **What a "4" answer sounds like:** "Use AWS Secrets Manager. Store the secret outside Terraform, reference it with a `data` source, and inject it into the ECS task definition using the `secrets` block (which pulls from Secrets Manager at runtime) instead of the `environment` block. Also mark the variable as `sensitive = true` and never set a default."

**3. ECS service not wired to ALB -- missing `load_balancer` block**
- File: `modules/ecs/main.tf` lines 182-195
- The `aws_ecs_service` has no `load_balancer` block. The ALB, listener, and target group are all created, but nothing registers ECS tasks into the target group. Traffic hits the ALB and gets a 503.
- **Blast radius:** The application deploys "successfully" (no Terraform errors) but serves zero traffic. This is a silent failure -- everything looks green but users get 503s.
- **What a "4" answer sounds like:** "The service needs a `load_balancer { target_group_arn = ..., container_name = ..., container_port = ... }` block. Without it, Fargate tasks launch but the ALB has no registered targets. This is the kind of bug `terraform plan` won't catch -- you need to understand the full request path."

**4. ECS tasks in public subnets with public IPs (cross-cutting)**
- Files: `terraform/main.tf` line 49 (passes `public_subnet_ids` to ECS module's `subnet_ids`), and `modules/ecs/main.tf` line 190 (`assign_public_ip = true`)
- The containers are deployed into public subnets with public IP addresses, bypassing the ALB as the single entry point. The containers are directly addressable from the internet.
- **Blast radius:** Containers are exposed to the internet. If the container has any vulnerability, it's directly exploitable. The three-tier architecture (ALB public -> ECS private -> RDS private) is broken.
- **What a "4" answer sounds like:** "The root module passes `public_subnet_ids` to the ECS module -- it should pass `private_subnet_ids`. And `assign_public_ip` should be `false` since the containers should egress through the NAT gateway, not have public IPs. The ALB is in public subnets (correct), but the containers must be in private subnets behind it."

#### Tier 2 -- Important (strong candidates will mention)

**5. Same IAM role for task_role_arn and execution_role_arn**
- File: `modules/ecs/main.tf` lines 148-149
- Both `execution_role_arn` and `task_role_arn` point to `aws_iam_role.ecs_execution_role.arn`. The execution role (for ECS infrastructure: pulling images, pushing logs) and the task role (for what the application code can do) should be separate.
- Violates least privilege: the application container inherits ECR pull and CloudWatch permissions it doesn't need.

**6. Health check on `/` with `matcher = "200"`, slow interval**
- File: `modules/ecs/main.tf` lines 79-87
- APIs typically don't serve 200 on `/`. Should use a dedicated `/healthz` endpoint. The 30s interval means 60s to detect an unhealthy container.

**7. RDS has `skip_final_snapshot = true`, no `deletion_protection`**
- File: `modules/database/main.tf` lines 53-54
- A `terraform destroy` or resource removal deletes the database with no backup and no safety net.

**8. No deployment circuit breaker on ECS service**
- File: `modules/ecs/main.tf` lines 182-195 (absent)
- A bad image push causes ECS to loop trying to launch failing tasks, eventually draining all healthy containers.

**9. Log group name mismatch**
- File: `modules/ecs/main.tf` line 130 creates `/ecs/${var.service_name}` (resolves to `/ecs/api`), but line 171 references `/ecs/${var.project_name}-${var.environment}` (resolves to `/ecs/api-platform-production`). Container will fail to start because the log group doesn't exist.

#### Tier 3 -- Best Practices (shows breadth)

- No HTTPS listener on ALB -- HTTP only on port 80 (`modules/ecs/main.tf` line 94)
- No `multi_az` on RDS, using `db.t3.micro` for production (`modules/database/main.tf`)
- No ECS autoscaling -- hardcoded `desired_count = 2` (`modules/ecs/main.tf` line 186)
- No `terraform {}` block, no provider version pinning (`terraform/main.tf`)
- No backend configuration -- local state (`terraform/main.tf`)
- Internet-facing ALB with no WAF (`modules/ecs/main.tf`)
- Container image uses `:latest` tag (`terraform/variables.tf` line 64)
- Single-AZ NAT gateway (`modules/networking/main.tf` line 72)
- `db_password` variable not marked `sensitive = true` (`modules/database/variables.tf`, `modules/ecs/variables.tf`)
- No `storage_encrypted` on RDS (`modules/database/main.tf`)
- No `backup_retention_period` on RDS (`modules/database/main.tf`)

---

## Phase 2: Architecture Deep-Dive (10 minutes)

### Prompt

> "Now let's go deeper. Two questions:
>
> 1. **Walk me through the full request path** -- from a user on the internet to the database. At each hop, what security controls exist and what's missing?
> 2. **What operational concerns** would keep you up at night if this went to production tonight?"

### Follow-Up Questions (pick 1-2)

- "How would you inject database credentials into the ECS tasks securely?"
- "The health check is configured for `/` with a 200 matcher. What would you change and why?"
- "What happens if a bad container image is deployed? Walk me through the failure mode."
- "How would you handle zero-downtime deployments with this setup?"

### Answer Key: Request Path Analysis

The expected request path walkthrough:

```
Internet
  -> ALB (port 80, HTTP only -- no TLS!)
    -> ECS Tasks (in public subnets -- wrong! should be private)
      -> RDS (publicly accessible + open SG -- exposed!)
```

**At each hop, a strong candidate should identify:**

| Hop | What exists | What's missing |
|-----|-------------|----------------|
| Internet -> ALB | SG allows port 80, ALB is internet-facing | No HTTPS/TLS (port 443), no WAF, no rate limiting |
| ALB -> ECS | SG allows container port from ALB SG | ECS in public subnets (should be private), public IPs assigned, no load_balancer block so ALB can't actually reach tasks |
| ECS -> RDS | DB password in plaintext env var | SG allows 0.0.0.0/0 (should be ECS SG only), RDS publicly accessible, no encryption in transit, same IAM role for task/execution |

### Answer Key: Operational Concerns

A strong candidate should discuss:

- **Deployment safety:** No circuit breaker means a bad image causes cascading failure. No rollback mechanism.
- **Monitoring gaps:** Log group name mismatch means container logs are lost. No CloudWatch alarms defined. No dashboards.
- **Data protection:** No deletion protection, no final snapshot, no automated backups configured.
- **Scaling:** Hardcoded `desired_count = 2` with no autoscaling. Under load, the service can't scale out.
- **Secrets management:** Password flowing through Terraform state and environment variables. No rotation strategy.
- **Reliability:** Single-AZ NAT gateway is a single point of failure for all private subnet egress.

---

## Phase 3: Architecture Design (12 minutes) -- THE KEY DIFFERENTIATOR

### Prompt

> "Set aside the bugs. You're the tech lead. You need to take this infrastructure to production for a team of 5 engineers across dev, staging, and production.
>
> 1. **How would you restructure this Terraform codebase?** Think: module organization, state management, environment separation, CI/CD.
> 2. **What AWS services are completely absent** that any production environment needs?
> 3. If I gave you **one week before go-live**, what would you prioritize?"

### Follow-Up Questions (pick 1-2)

- "How would you set up CI/CD for this infrastructure?"
- "How would you handle database migrations in this architecture?"
- "What does your monitoring and alerting story look like end-to-end?"
- "How would you handle a scenario where the ECS service needs to connect to a third-party API that requires IP whitelisting?"

### Answer Key

#### Codebase Structure

**Meets expectations (3):** Proposes environment separation (dev/staging/prod directories or Terragrunt), module versioning (Git tags or registry), shared configuration, and a bootstrap layer for the state bucket.

**Exceeds (4):** Discusses module registry, semantic versioning, automated module testing (terratest), CODEOWNERS for production, module documentation strategy.

#### State Management

**Meets (3):** S3 + DynamoDB for remote state with locking, per-environment state files, access control, awareness of the bootstrap chicken-and-egg problem.

**Exceeds (4):** Cross-account state for multi-account strategy, state encryption with CMK, state backup/recovery, import workflows.

#### Security Architecture

**Meets (3):** Network segmentation (public ALB / private ECS / private RDS), TLS termination at ALB, secrets in Secrets Manager, IAM least privilege with separate task/execution roles.

**Exceeds (4):** VPC endpoints for ECR/S3/CloudWatch (eliminates NAT dependency for AWS services), WAF rules, CloudTrail, AWS Config, VPC Flow Logs, Security Hub, SCPs at the organization level, encryption at rest with CMKs.

#### Reliability & Scaling

**Meets (3):** ECS autoscaling (target tracking on CPU/memory), multi-AZ NAT gateways, RDS multi-AZ, deployment circuit breaker with rollback, health check tuning, automated backups.

**Exceeds (4):** RDS read replicas, Performance Insights, cross-region DR strategy with defined RTO/RPO, ECS capacity providers, SQS-based decoupling for async workloads, chaos engineering (AWS FIS).

#### CI/CD for Infrastructure

**Meets (3):** `terraform plan` on PR with review, `terraform apply` on merge, separate pipelines per environment with promotion flow, policy-as-code scanning (tfsec/checkov).

**Exceeds (4):** Drift detection, cost estimation in PRs (Infracost), OIDC for CI/CD auth (no long-lived credentials), image scanning in ECR, blue/green deployments with CodeDeploy, separate image build pipeline from infra pipeline.

---

## Bonus: Terragrunt (only if Phase 3 finishes early)

### Prompt

> "If you were to wrap this in Terragrunt for multi-environment deployment, how would you structure it? What configuration would live where?"

### What this tests

Conceptual understanding of Terragrunt's value proposition:
- DRY configuration with `include` and `dependency` blocks
- Generated backend configs per environment
- `run_all` for orchestrating multi-module applies
- When Terragrunt adds value vs. when it adds complexity
- Trade-offs vs. directory-based separation or Terraform workspaces

---

## Scoring Rubric

### Scale

| Score | Label | Description |
|-------|-------|-------------|
| 1 | Below expectations | Misses the point or gives incorrect information |
| 2 | Developing | Touches the topic but lacks depth or accuracy |
| 3 | Meets expectations | Solid understanding with clear reasoning |
| 4 | Exceeds expectations | Deep expertise, non-obvious insights, real-world experience |

### Phase 1: Triage (max 12 points)

| Criterion | 1 | 2 | 3 | 4 |
|-----------|---|---|---|---|
| **Security** | Misses public DB + open SG | Notices one of the two | Identifies both, explains blast radius | Also proposes SG-reference fix, mentions compliance |
| **Functional correctness** | Misses missing load_balancer block | Notices ALB exists but doesn't see it's unwired | Identifies ALB not connected to ECS, explains 503 | Also catches log group mismatch as a startup failure |
| **Secrets management** | Misses plaintext password | Notices password exists but not the full flow | Identifies password in variables.tf + env vars + state | Proposes Secrets Manager with ECS secrets block, discusses rotation |

### Phase 2: Deep-Dive (max 16 points)

| Criterion | 1 | 2 | 3 | 4 |
|-----------|---|---|---|---|
| **Request path analysis** | Cannot trace the path | Traces partially, misses gaps | Full path with security gaps at each hop | Also identifies the public subnet / assign_public_ip cross-cutting issue |
| **IAM understanding** | Doesn't mention IAM | Notices a role exists | Identifies task vs execution role conflation, explains why it matters | Discusses what permissions each role should have, mentions IAM Access Analyzer |
| **Operational reasoning** | No day-2 concerns | Says "monitoring" generically | Specific gaps: no circuit breaker, no autoscaling, log mismatch, no backups | End-to-end story: structured logging, metrics, alarms, dashboards, runbooks, on-call |
| **Cross-module awareness** | Doesn't look across files | Reads each module independently | Connects root main.tf wiring to module behavior (wrong subnets) | Traces the full data flow: password from variables.tf through main.tf to both modules |

### Phase 3: Architecture Design (max 20 points) -- PRIMARY GATE

| Criterion | 1 | 2 | 3 | 4 |
|-----------|---|---|---|---|
| **Codebase structure** | No improvement suggested | Basic env folders | Module versioning, env separation, clear trade-offs | Registry, testing, CODEOWNERS, documentation |
| **State management** | Doesn't address it | Remote state without details | S3+DynamoDB, per-env, access control, bootstrap | Cross-account, encryption, recovery, imports |
| **Security architecture** | Only fixes existing bugs | Mentions "IAM" and "encryption" | Network segmentation, TLS, Secrets Manager, least-privilege | VPC endpoints, WAF, CloudTrail, Config, SCPs |
| **Reliability & scaling** | Doesn't discuss | "Add autoscaling" | ECS autoscaling, multi-AZ, circuit breaker, backups | DR strategy, RTO/RPO, read replicas, chaos engineering |
| **CI/CD for infra** | Doesn't mention | "Run terraform in CI" | Plan on PR, apply on merge, policy-as-code | Drift detection, cost estimation, OIDC, image scanning |

### Pass/Fail Thresholds

| Decision | Criteria |
|----------|----------|
| **Pass** | Phase 1 >= 6 AND Phase 2 >= 8 AND Phase 3 >= 12 AND Total >= 30/48 |
| **Strong hire** | Total >= 38 with Phase 3 >= 16 |
| **Exceptional** | Total >= 42 with Phase 3 >= 18 |

### Automatic Fail Signals (any one = fail)

- Cannot identify the publicly accessible RDS + open SG as a security issue
- Cannot explain the difference between task role and execution role (or ECS IAM model)
- Cannot describe how to structure Terraform for multiple environments
- Shows no awareness of secrets management beyond "don't hardcode passwords"
- Cannot articulate a deployment safety strategy

---

## Interviewer Tips

### Time Management

- If Phase 1 finishes in 5 minutes, bank the extra time for Phase 3 (the most important phase).
- If they're struggling at 8 minutes, briefly wrap up and move on. Phase 3 signal is more valuable.
- **Never cut Phase 3 short.** It's better to shorten Phase 2 than Phase 3.

### Green Flags

- Asks clarifying questions: "What's the threat model? What compliance requirements?"
- Prioritizes by blast radius, not by line number
- Connects issues across modules: "The root passes public subnets to ECS, and the container has a public IP..."
- Proposes systemic fixes: "Instead of fixing bugs one by one, let's restructure..."
- Mentions tools: tfsec, checkov, Terraform Cloud, Infracost, OIDC, policy-as-code

### Red Flags

- Reads sequentially from line 1 instead of scanning for patterns
- States *that* something is wrong but not *why* it matters
- Proposes fixes that create new problems
- Has no mental model for multi-environment Terraform
- Cannot discuss IAM beyond "it needs permissions"
- Fixates on cosmetic issues (naming, formatting) while missing security/architecture gaps

### Calibration

Don't penalize missing the NAT gateway HA issue (Tier 3) if they nail the database security and architecture discussion. The rubric is weighted toward Phase 3 intentionally. Conversely, a candidate who finds every syntax issue but can't discuss state management should not pass.

---

## Score Sheet

```
Candidate: ________________  Date: ________________  Interviewer: ________________

PHASE 1: TRIAGE (8 min)                           Score
  Security (public DB + open SG)                   [ ] /4
  Functional correctness (ALB not wired)           [ ] /4
  Secrets management (plaintext password)          [ ] /4
  Phase 1 subtotal:                                [ ] /12  (min 6 to pass)

PHASE 2: DEEP-DIVE (10 min)
  Request path analysis                            [ ] /4
  IAM understanding (task vs execution role)       [ ] /4
  Operational reasoning                            [ ] /4
  Cross-module awareness                           [ ] /4
  Phase 2 subtotal:                                [ ] /16  (min 8 to pass)

PHASE 3: ARCHITECTURE DESIGN (12 min)
  Codebase structure                               [ ] /4
  State management strategy                        [ ] /4
  Security architecture                            [ ] /4
  Reliability & scaling                            [ ] /4
  CI/CD for infrastructure                         [ ] /4
  Phase 3 subtotal:                                [ ] /20  (min 12 to pass)

TOTAL:                                             [ ] /48  (min 30 to pass)

Terragrunt bonus (if applicable):                  [ ] /4

DECISION:  [ ] Pass  [ ] Strong Hire  [ ] No Hire

Auto-fail triggered?  [ ] Yes -- which: _______________  [ ] No

Notes:
_______________________________________________
_______________________________________________
_______________________________________________
```
