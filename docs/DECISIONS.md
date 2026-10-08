# Decisions

Why it's built this way, and what each choice cost.

---

## Deploy with SSM Run Command, not SSH

The pipeline sends the deploy commands to the server through SSM, using the `AWS-RunShellScript` document. There's no port 22 open and no SSH key anywhere.

The usual alternative is an SSH key stored in GitHub Secrets. That means an open port that bots knock on all day (my logs showed them trying within hours), and a long-lived key that can leak. With SSM, access is just IAM permissions, and every command is recorded.

What it cost: the server needs the SSM agent and an IAM role, and the deploy role needs exact SSM permissions. I also scoped `ssm:SendCommand` to instances tagged `Project = aws-automated-deployment-pipeline`, so the pipeline can't run commands on anything else in my account.

## OIDC instead of AWS access keys

GitHub Actions asks GitHub for a short-lived ID token, and AWS swaps it for temporary credentials for one role. Nothing secret is stored in GitHub. There's nothing to rotate and nothing to leak.

The trust policy only accepts tokens from this repo's `main` branch, matched on the permanent owner and repo IDs. Getting that exact match right was my hardest bug (incident 1).

## Images tagged with the commit SHA, and immutable

Every image is tagged with `github.sha`, and the ECR repo has immutable tags. So the tag tells me exactly which code is inside, and nobody can quietly overwrite it. The app also reports that SHA as its version, so the health check can confirm the right code is live.

What it cost: you can't push the same tag twice. "Re-run all jobs" on an old run fails at the push step, so I redeploy with a new commit instead (incident 7).

## Trivy pinned to a commit SHA

In March 2026 attackers moved trivy-action's version tags to point at malicious code. A tag can be moved, but a commit SHA can't, so the pipeline uses the full SHA with the version written next to it as a comment. The scan fails the build on any CRITICAL or HIGH vulnerability that has a fix available. Ones with no fix yet are ignored, otherwise the build would fail on things I can't do anything about.

## One EC2 instance running Docker

The brief asked for EC2 with Docker, and one t3.micro keeps the cost close to nothing. The deploy is simple: pull, remove the old container, start the new one.

What it cost: a few seconds of downtime on each deploy, and no redundancy. With more traffic, I'd put two or more instances behind a load balancer, or move to ECS with rolling deploys.

## Terraform from my laptop, separate from the app pipeline

The brief lists CI/CD and Terraform as separate parts, and many teams keep them apart too. Changing infrastructure is riskier than changing app code, so it shouldn't happen on every merge.

So Terraform builds the infrastructure once, and the pipeline only deploys the app onto it. That's why moving from my hand-built setup to Terraform needed no pipeline change: the pipeline finds the server by its `Name` tag, and its permissions use the `Project` tag and the ECR repo name. Terraform created all three the same way.

What it cost: applies run from my laptop with my IAM user. The next step would be a separate Terraform pipeline, with plan on PR and apply after approval. I've built one before in another project.

## Remote state in S3 with native locking

The state file is Terraform's record of what it built. Kept on my laptop, it's lost if the laptop dies. So it lives in a versioned, encrypted S3 bucket, with `use_lockfile = true`. Since Terraform 1.11, the S3 backend can lock using a lock file in the bucket itself, so I didn't need a DynamoDB table (that approach is now deprecated).

What it cost: the bucket has to exist before Terraform can use it, so I made it by hand. Terraform can't create the bucket that holds its own state.

## Monitoring built in Terraform too

The brief doesn't say how to set up monitoring. I put the log group, the log-writing permission, the SNS topic and email, and the CPU alarm in `monitoring.tf`, for two reasons. The server's IAM role was built by Terraform, so adding a permission to it by hand would create drift. And one `terraform destroy` removes everything, so nothing is left behind costing money.

## Container logs through Docker's awslogs driver

The container writes to stdout, and Docker sends each line to CloudWatch Logs. The pipeline sets the log options when it starts the container. Each deploy writes to a stream named after its commit SHA, so I can tell which version wrote which line. The log group keeps 7 days, because CloudWatch keeps logs forever by default, and so does the bill.

I didn't use the CloudWatch agent, because I only needed container logs. It's the right tool if I also want memory and disk metrics.

## The CPU alarm: 70%, one 5-minute period

70% gives a warning before the server is maxed out. One period made the test quick (ALARM about 3 minutes after the load started). Missing data counts as "not breaching", so stopping the server doesn't set it off. It emails on both ALARM and OK, so I know when a problem ends.

In production I'd use 2–3 periods, so a short spike doesn't wake anyone, and add an alarm on `CPUCreditBalance`. A t3 in standard mode is held at 10% CPU when its credits run out, and the CPU alarm wouldn't notice the app starving.

## Branches: feature → develop → main

Work happens on `feature/*` branches, goes into `develop` by PR, and is released to `main` by another PR. Both PRs run the checks, but only `main` deploys. Branch protection requires Lint and Test plus Build and Security Scan to pass, with no bypass. I turned off "require branches to be up to date", because with only me working on it, that just blocked my release PRs.

## Runner pinned to ubuntu-24.04

`ubuntu-latest` moves to a new Ubuntu version on GitHub's schedule. Pinning means an upgrade happens when I choose, not in the middle of a deploy.

## Docs changes skip the deploy

The push trigger ignores `README.md`, `docs/**`, `screenshots/**` and `architecture.png`. Editing documentation doesn't need a new image or a deploy. And now that the infrastructure is destroyed, a README fix won't start a deploy that has no server to go to. PRs still run the checks, because branch protection waits for them.
