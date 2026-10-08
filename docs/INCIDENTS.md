# Incidents

Every real problem from this build, written up the way teams write up incidents at work: what I saw, what was actually wrong, how it was fixed, and the lesson.

---

## 1. The pipeline couldn't log in to AWS

**Symptom**
The first push to `main` failed at the OIDC login step:
```
Not authorized to perform sts:AssumeRoleWithWebIdentity
```
Re-running the job gave the same error.

**Cause**
CloudTrail Event history (AWS's record of every API call), filtered on `AssumeRoleWithWebIdentity`, showed the rejected login. The subject GitHub sent was:
```
repo:muralidharan666666-dev@226997318/aws-automated-deployment-pipeline@1404309788:ref:refs/heads/main
```
GitHub now adds the permanent owner ID and repo ID to the subject. It does that so a deleted or renamed repo name can't be taken by someone else and used to get into my AWS role. My trust policy only had the names, so it never matched.

**Fix**
The trust policy (the rule saying who may use the role) was changed to match that exact subject with `StringEquals` (plus `aud = sts.amazonaws.com`). After "Re-run failed jobs", it passed.

**Lesson**
When a login to an AWS role fails, check CloudTrail first. It shows exactly what was rejected, so there's no guessing.

---

## 2. My `.gitignore` wasn't ignoring anything

**Symptom**
`__pycache__/*.pyc` files showed up in a PR. I ran `git rm --cached`, then `git add .`, and they were added straight back.

**Cause**
`cat .gitignore` showed every line starting with 2 spaces, from pasting indented text. To Git, `  __pycache__/` isn't the same pattern as `__pycache__/`, so nothing on the list was ignored. That included `.env` and `*.pem`.

**Fix**
I rewrote the file exactly with `printf`, ran `git rm -r --cached` on the folder, committed `chore: fix .gitignore and stop tracking __pycache__ files`, and the PR re-ran clean.

**Lesson**
Read the PR's "Files changed" tab before merging. Anything there I didn't mean to add is a warning sign.

---

## 3. Invisible Windows line endings, and a server that could have been replaced

**Symptom**
Before committing the monitoring work, `git status` showed `ec2.tf`, `ecr.tf`, `network.tf`, `security.tf` and `versions.tf` as modified. I hadn't edited any of them.

**Cause**
`git diff --stat` and `git diff --ignore-cr-at-eol --stat` both showed only my 3 real changes, so the other 5 were line endings only. Git for Windows (`core.autocrlf=true`) stores LF in the repo but writes CRLF to the laptop. I had stripped the `\r` with `sed`, which made them look changed.

That matters here because `ec2.tf` contains the user data script, and it has `user_data_replace_on_change = true`. A hidden `\r` in that script counts as a change, so Terraform would replace the server. It could also break the script itself, because Linux can't run `#!/bin/bash\r`.

**Fix**
I added `.gitattributes`:
```
*.tf text eol=lf
*.hcl text eol=lf
```
I committed it on its own: `chore: force LF line endings for Terraform files`.

**Lesson**
Set line endings in the repo, not on each laptop. My laptop runs Windows, but every server here is Linux.

---

## 4. My email address nearly went into a public repo

**Symptom**
`git status` listed `terraform/terraform.tfvars` as a new file. That file holds my real alert email. `.gitignore` wasn't even showing as modified.

**Cause**
The `*.tfvars` line I meant to add to `.gitignore` had never been saved.

**Fix**
I added it with `printf '\n*.tfvars\n' >> .gitignore` and checked `git status` again. The file was gone from the list. I committed only `terraform.tfvars.example`, which has a placeholder address.

**Lesson**
Read `git status` before every `git add`, and name the files instead of using `git add .`.

---

## 5. The AWS CLI was pointing at the wrong region

**Symptom**
`aws sns list-subscriptions-by-topic` failed with `InvalidParameter: TopicArn`, even though the ARN was correct. Earlier in the project, my first EC2 launch had also landed in N. Virginia by mistake.

**Cause**
`aws configure get region` returned `us-east-1`. Everything in this project is in `ap-south-1`. SNS in another region can't find a Mumbai topic. Terraform wasn't affected, because its region is set in the code.

**Fix**
I added `--region ap-south-1` to the command, and it worked straight away.

**Lesson**
State the region in every CLI command and script, instead of trusting the default.

---

## 6. Gunicorn workers kept timing out in Docker

**Symptom**
When I first ran the container locally, the logs showed `WORKER TIMEOUT` errors with a traceback, then `Worker exiting`.

**Cause**
Gunicorn's default is one sync worker that handles one request at a time. A slow or hanging connection holds it until the timeout kills it.

**Fix**
I changed the command to 2 workers with 4 threads each (`--workers 2 --threads 4`, which makes Gunicorn use threaded workers) and turned on access logs with `--access-logfile -`. The timeouts stopped.

**Lesson**
Check how the app server is set up, not just whether the app code works.

---

## 7. "Re-run all jobs" can't work with immutable tags

**Symptom**
After fixing the OIDC problem, I used "Re-run failed jobs", and Lint and Test showed its old result instead of running again.

**Cause**
"Re-run failed jobs" only runs the failed and skipped jobs, and keeps the ones that already passed. "Re-run all jobs" would rebuild and try to push the same commit SHA tag. ECR refuses that, because the tags are immutable.

**Fix**
None needed. Re-running only the failed jobs was the right choice.

**Lesson**
To redeploy, push a new commit (or a revert). Don't re-push an existing tag. That's the trade-off for tags that can never be overwritten.
