# GitHub CLI (`gh`) Command Cheat Sheet

## Part 1: Authentication & Configuration

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `gh auth login` | `$ gh auth login`<br>`? What account do you want to log into? GitHub.com`<br>`? What is your preferred protocol for Git operations? HTTPS`<br>`? Authenticate Git with your GitHub credentials? Yes`<br>`✓ Logged in as username` | First-time setup or adding new account | Authenticates CLI with GitHub; enables all other `gh` commands |
| `gh auth logout` | `$ gh auth logout --hostname github.com`<br>`✓ Logged out of github.com account 'username'` | Remove account credentials | Security cleanup when leaving shared machine |
| `gh auth status` | `$ gh auth status`<br>`github.com`<br>`  ✓ Logged in to github.com as username (keyring)`<br>`  ✓ Git operations for github.com configured to use https protocol.` | Verify authentication state | Troubleshoot permission errors; confirm active account |
| `gh auth switch` | `$ gh auth switch --user work-account`<br>`✓ Switched active account for github.com to work-account` | Toggle between multiple accounts | Manage personal vs. work GitHub accounts seamlessly |
| `gh auth token` | `$ gh auth token`<br>`ghp_xxxxxxxxxxxxxxxxxxxx` | Retrieve API token for scripts | Use in CI/CD pipelines or external tools requiring GitHub API access |
| `gh auth setup-git` | `$ gh auth setup-git`<br>`✓ Configured git protocol`<br>`✓ Uploaded the SSH key to your GitHub account` | Configure git to use gh credentials | Single sign-on for both `git` and `gh` commands |
| `gh config set` | `$ gh config set editor vim`<br>`$ gh config set prompt disabled` | Customize gh behavior | Set preferred editor, disable prompts for scripting |
| `gh config get` | `$ gh config get editor`<br>`vim` | Check current settings | Verify configuration before running commands |

## Part 2: Repository Operations

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `gh repo clone` | `$ gh repo clone cli/cli`<br>`Cloning into 'cli'...`<br>`remote: Enumerating objects: 50000, done.`<br>`✓ Cloned fork and added remote 'upstream'` | Download repository | Auto-adds upstream remote for forks; cleaner than `git clone` |
| `gh repo create` | `$ gh repo create my-project --public --source=. --push`<br>`✓ Created repository username/my-project on GitHub`<br>`✓ Added remote https://github.com/username/my-project.git`<br>`✓ Pushed commits to https://github.com/username/my-project.git` | Create new GitHub repository | One-command repo creation with local linking and push |
| `gh repo fork` | `$ gh repo fork kubernetes/kubernetes --clone --remote`<br>`✓ Created fork username/kubernetes`<br>`✓ Cloned fork`<br>`✓ Added remote origin` | Fork existing repository | Essential for contributing to open source; sets up remotes automatically |
| `gh repo view` | `$ gh repo view cli/cli --web`<br>`Opening https://github.com/cli/cli in your browser.` | Open repository in browser | Quick navigation; `--web` opens browser, omit for CLI details |
| `gh repo list` | `$ gh repo list microsoft --limit 10 --json name,stargazersCount`<br>`[{"name":"vscode","stargazersCount":150000},...]` | List user/org repositories | Audit repos, find popular projects, generate reports |
| `gh repo delete` | `$ gh repo delete my-old-repo --yes`<br>`✓ Deleted repository username/my-old-repo` | Remove repository | Cleanup with `--yes` to skip confirmation in scripts |
| `gh repo archive` | `$ gh repo archive legacy-project`<br>`✓ Archived repository username/legacy-project` | Archive inactive repositories | Preserves code while indicating project status |
| `gh repo sync` | `$ gh repo sync`<br>`✓ Fetched upstream`<br>`✓ Fast-forwarded main to upstream/main` | Sync fork with upstream | Keep fork updated without manual git commands |

## Part 3: Pull Request Management

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `gh pr create` | `$ gh pr create --title "Fix login bug" --body "Resolves #123" --draft`<br>`Creating pull request for feature-branch into main in owner/repo`<br>`https://github.com/owner/repo/pull/456` | Submit changes for review | Creates PR with metadata; `--draft` for work-in-progress |
| `gh pr list` | `$ gh pr list --state open --author "@me" --limit 5`<br>`Showing 3 of 3 open pull requests in owner/repo`<br>`#456  Fix login bug    feature-branch  about 2 hours ago`<br>`#455  Update docs      docs-update     about 1 day ago` | View open pull requests | Track your work; filter by author, state, or branch |
| `gh pr view` | `$ gh pr view 456 --web`<br>`Opening https://github.com/owner/repo/pull/456 in your browser.` | Open specific PR | Review details; `--web` for full GitHub interface |
| `gh pr checkout` | `$ gh pr checkout 456`<br>`branch 'feature-branch' set up to track 'origin/feature-branch'.`<br>`Switched to a new branch 'feature-branch'` | Test PR locally | Auto-configures tracking; essential for code review |
| `gh pr merge` | `$ gh pr merge 456 --squash --delete-branch`<br>`✓ Squashed and merged pull request #456 (Fix login bug)`<br>`✓ Deleted remote branch feature-branch`<br>`✓ Deleted local branch feature-branch` | Complete PR workflow | Multiple merge strategies; auto-cleanup with `--delete-branch` |
| `gh pr diff` | `$ gh pr diff 456`<br>`diff --git a/src/login.js b/src/login.js`<br>`-    const token = req.query.token;`<br>`+    const token = req.body.token;` | Review changes without browser | Fast CLI diff review; pipe to `less` or files |
| `gh pr review` | `$ gh pr review 456 --approve --body "LGTM! 🚀"`<br>`✓ Approved pull request #456` | Submit PR review | Approve, request changes, or comment from terminal |
| `gh pr checks` | `$ gh pr checks 456 --watch`<br>`Some checks are still pending`<br>`0 failures, 1 pending, 2 successful`<br>`✓ All checks successful` | Monitor CI status | `--watch` polls until completion; essential before merging |
| `gh pr close` | `$ gh pr close 456 --comment "Superseded by #457"`<br>`✓ Closed pull request #456` | Abandon PR | Clean close with explanatory comment |
| `gh pr reopen` | `$ gh pr reopen 456`<br>`✓ Reopened pull request #456` | Resume closed PR | Reactivate accidentally closed or premature closures |
| `gh pr ready` | `$ gh pr ready 456`<br>`✓ Marked pull request #456 as ready for review` | Convert draft to ready | Signal PR completion after draft stage |

## Part 4: Issue Management

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `gh issue create` | `$ gh issue create --title "Bug: Login fails" --body "Steps to reproduce..." --label bug`<br>`Creating issue in owner/repo`<br>`https://github.com/owner/repo/issues/789` | Report bugs or features | Structured issue creation with labels and assignees |
| `gh issue list` | `$ gh issue list --state open --label "help wanted" --limit 10`<br>`Showing 5 of 23 open issues in owner/repo`<br>`#789  Bug: Login fails       about 2 hours ago`<br>`#788  Feature: Dark mode     about 1 day ago` | Browse open issues | Find work items; filter by labels, milestones, assignees |
| `gh issue view` | `$ gh issue view 789`<br>`title:\tBug: Login fails`<br>`state:\tOPEN`<br>`author:\treporter`<br>`labels:\tbug, high-priority` | Read issue details | Quick CLI view without browser context switch |
| `gh issue close` | `$ gh issue close 789 --comment "Fixed in #456"`<br>`✓ Closed issue #789` | Resolve issues | Link to fixing PR for traceability |
| `gh issue reopen` | `$ gh issue reopen 789`<br>`✓ Reopened issue #789` | Revisit closed issues | Reopen if bug persists or prematurely closed |
| `gh issue status` | `$ gh issue status`<br>`Issues assigned to you`<br>`  #789 Bug: Login fails [owner/repo]`<br>`Issues mentioning you`<br>`  #456 Review requested [owner/repo]` | Track your issues | Personalized dashboard of relevant issues |
| `gh issue comment` | `$ gh issue comment 789 --body "Can reproduce on Safari"` | Add comments | Participate in discussions from terminal |
| `gh issue edit` | `$ gh issue edit 789 --add-label "confirmed" --remove-label "needs-triage"` | Modify issue metadata | Update labels, assignees, milestones programmatically |
| `gh issue transfer` | `$ gh issue transfer 789 owner/other-repo`<br>`✓ Transferred issue #789 to owner/other-repo` | Move issues between repos | Reorganize when issues filed in wrong repository |
| `gh issue pin` | `$ gh issue pin 789`<br>`✓ Pinned issue #789` | Highlight important issues | Pin critical bugs or FAQs for visibility |

## Part 5: GitHub Actions (Workflows)

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `gh run list` | `$ gh run list --limit 5`<br>`Showing 5 recent workflow runs`<br>`✓  main  CI  push  3m36s  3af5d2e  about 1 hour ago`<br>`✗  main  CI  push  2m10s  7b8c9d1  about 2 hours ago` | View recent workflow runs | Monitor CI health; identify failing builds |
| `gh run view` | `$ gh run view 1234567890 --web`<br>`Opening https://github.com/owner/repo/actions/runs/1234567890` | Inspect specific run | Deep dive into logs and job details |
| `gh run watch` | `$ gh run watch 1234567890`<br>`✓ Run 1234567890 (CI) completed with 'success'` | Monitor running workflow | Real-time CI progress without browser refresh |
| `gh run rerun` | `$ gh run rerun 1234567890 --failed`<br>`✓ Requested rerun of run 1234567890` | Retry failed jobs | Quick retry after flaky test or transient failure |
| `gh run download` | `$ gh run download 1234567890 --name artifact-name`<br>`✓ Downloaded artifact-name.zip` | Retrieve build artifacts | Download test reports, build outputs, or binaries |
| `gh workflow list` | `$ gh workflow list`<br>`CI          active  3456`<br>`Release     active  3457`<br>`Nightly     disabled 3458` | List available workflows | Discover automation available in repository |
| `gh workflow view` | `$ gh workflow view ci.yml --web`<br>`Opening https://github.com/owner/repo/actions/workflows/ci.yml` | Inspect workflow definition | Review YAML configuration and recent runs |
| `gh workflow run` | `$ gh workflow run deploy.yml --ref main -f environment=production`<br>`✓ Created workflow_dispatch event for deploy.yml` | Trigger manual workflow | Deploy on demand with custom inputs |
| `gh workflow enable` | `$ gh workflow enable nightly.yml`<br>`✓ Enabled workflow nightly.yml` | Activate disabled workflows | Resume scheduled or manual workflows |
| `gh workflow disable` | `$ gh workflow disable obsolete.yml`<br>`✓ Disabled workflow obsolete.yml` | Pause workflows | Temporarily stop without deleting YAML |

## Part 6: Releases & Packages

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `gh release create` | `$ gh release create v1.2.3 --title "Version 1.2.3" --notes "Bug fixes" dist/*.tar.gz`<br>`https://github.com/owner/repo/releases/tag/v1.2.3`<br>`✓ Uploaded dist/app-linux.tar.gz` | Publish new release | Automate release process with artifacts |
| `gh release list` | `$ gh release list --limit 5`<br>`TITLE     TYPE    TAG NAME  PUBLISHED`<br>`v1.2.3    Latest  v1.2.3    about 2 days ago`<br>`v1.2.2            v1.2.2    about 1 week ago` | View release history | Track versioning; find latest stable release |
| `gh release view` | `$ gh release view v1.2.3`<br>`title:\tVersion 1.2.3`<br>`tag:\tv1.2.3`<br>`draft:\tfalse`<br>`prerelease:\tfalse` | Inspect release details | Verify release metadata before announcing |
| `gh release download` | `$ gh release download v1.2.3 --pattern '*.tar.gz'`<br>`✓ Downloaded app-linux.tar.gz`<br>`✓ Downloaded app-macos.tar.gz` | Fetch release assets | Automated deployment or local installation |
| `gh release upload` | `$ gh release upload v1.2.3 checksums.txt`<br>`✓ Uploaded checksums.txt to release v1.2.3` | Add files to existing release | Attach additional artifacts like signatures |
| `gh release delete` | `$ gh release delete v1.2.3 --yes`<br>`✓ Deleted release v1.2.3` | Remove erroneous releases | Cleanup failed or premature releases |
| `gh release edit` | `$ gh release edit v1.2.3 --draft=false --prerelease=false` | Modify release properties | Convert draft to final or mark as stable |

## Part 7: Secrets & Variables

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `gh secret set` | `$ gh secret set API_KEY --body "secret123"`<br>`✓ Set Actions secret API_KEY for owner/repo` | Store sensitive data | Encrypt secrets for GitHub Actions; never expose in code |
| `gh secret list` | `$ gh secret list`<br>`NAME          UPDATED`<br>`API_KEY       about 2 days ago`<br>`DATABASE_URL  about 1 week ago` | Audit repository secrets | Security review; verify necessary secrets exist |
| `gh secret delete` | `$ gh secret delete OLD_KEY`<br>`✓ Deleted Actions secret OLD_KEY for owner/repo` | Remove obsolete secrets | Cleanup rotated or deprecated credentials |
| `gh variable set` | `$ gh variable set NODE_VERSION --body "18.x"`<br>`✓ Set Actions variable NODE_VERSION for owner/repo` | Store non-sensitive config | Reusable configuration values across workflows |
| `gh variable list` | `$ gh variable list`<br>`NAME           VALUE`<br>`NODE_VERSION   18.x`<br>`DEPLOY_REGION  us-east-1` | Review configuration variables | Audit environment settings |
| `gh variable delete` | `$ gh variable delete DEPRECATED_VAR`<br>`✓ Deleted Actions variable DEPRECATED_VAR` | Cleanup old variables | Maintain clean configuration surface |

## Part 8: Advanced & API

| Command | Example with Output | When to Use | Why |
|---------|---------------------|-------------|-----|
| `gh api` | `$ gh api repos/owner/repo/issues --jq '.[] \| {title: .title, number: .number}'`<br>`{"title":"Bug report","number":123}` | Raw GitHub API access | Access endpoints without native `gh` commands |
| `gh browse` | `$ gh browse 456 --repo cli/cli`<br>`Opening https://github.com/cli/cli/pull/456 in your browser.` | Quick navigation to issues/PRs | Faster than typing URLs; works from any directory |
| `gh copilot` | `$ gh copilot suggest "commit message for these changes"`<br>`✓ Copilot suggests: "Fix authentication in login flow"` | AI-powered assistance | Generate commit messages, explain code, suggest commands |
| `gh extension install` | `$ gh extension install dlvhdr/gh-dash`<br>`✓ Installed extension dlvhdr/gh-dash` | Add community extensions | Customize `gh` with enhanced dashboards or utilities |
| `gh extension list` | `$ gh extension list`<br>`NAME         REPO              VERSION`<br>`gh dash      dlvhdr/gh-dash    v3.0.0`<br>`gh poi       seachicken/gh-poi v0.9.0` | View installed extensions | Manage and update community plugins |
| `gh alias set` | `$ gh alias set co "pr checkout"`<br>`$ gh co 456`<br>`✓ Checked out PR #456` | Create command shortcuts | Reduce typing for frequently used commands |
| `gh alias list` | `$ gh alias list`<br>`co: pr checkout`<br>`st: pr status` | Review custom aliases | Document and share team shortcuts |
| `gh cache list` | `$ gh cache list`<br>`ID  KEY            SIZE     CREATED`<br>`12  Linux-node-...  156 MB   2 days ago` | Monitor Actions cache usage | Optimize CI costs and performance |
| `gh cache delete` | `$ gh cache delete --all --confirm`<br>`✓ Deleted 15 caches` | Cleanup old cache entries | Free storage space; troubleshoot cache issues |
| `gh gist create` | `$ gh gist create script.sh --public --desc "Utility script"`<br>`Creating gist script.sh`<br>`https://gist.github.com/username/abc123` | Share code snippets | Quick sharing without full repository |
| `gh gist list` | `$ gh gist list --limit 5`<br>`ID          DESCRIPTION           FILES  VISIBILITY`<br>`abc123      Utility script        1      public`<br>`def456      Config example        3      secret` | Manage your gists | Browse and find previously shared snippets |
| `gh gist view` | `$ gh gist view abc123 --raw`<br>`#!/bin/bash`<br>`echo "Hello World"` | Display gist content | View without browser; `--raw` for piping |
| `gh gist edit` | `$ gh gist edit abc123`<br>`✓ Edited gist abc123` | Modify existing gists | Update shared snippets with improvements |
| `gh gist delete` | `$ gh gist delete abc123`<br>`✓ Deleted gist abc123` | Remove obsolete gists | Cleanup temporary or sensitive snippets |
| `gh completion` | `$ gh completion -s bash >> ~/.bashrc` | Generate shell completions | Tab completion for `gh` commands and flags |
| `gh help` | `$ gh help pr create`<br>`Create a pull request...` | Learn command usage | Built-in documentation; explore available flags |

---

## Quick Reference: Common Workflows

| Task | Command Sequence |
|------|------------------|
| **Start new feature** | `git checkout -b feature` → work → `git commit` → `gh pr create --draft` |
| **Review PR** | `gh pr list` → `gh pr checkout 123` → test → `gh pr review 123 --approve` |
| **Deploy release** | `gh workflow run deploy.yml` → `gh run watch` → `gh release create v1.0.0` |
| **Clean up merged PR** | `gh pr merge 123 --squash --delete-branch` → `git pull` |
| **Find work items** | `gh issue status` → `gh pr status` → `gh issue list --assignee "@me"` |
| **Troubleshoot CI** | `gh run list --failed` → `gh run view 123 --log-failed` → `gh run rerun 123` |

---

## Pro Tips

1. **JSON output**: Use `--json` with `jq` for scripting: `gh pr list --json number,title --jq '.[] | select(.title | contains("urgent"))'`
2. **Web fallback**: Most commands support `--web` to open GitHub when CLI isn't enough
3. **Aliases**: Create shortcuts for your workflow: `gh alias set web "browse --web"`
4. **Shell completion**: Enable tab completion: `gh completion -s zsh > "${fpath[1]}/_gh"`
5. **Dry runs**: Use `--dry-run` for `pr create` to preview without submitting
6. **Template files**: Create `.github/PULL_REQUEST_TEMPLATE.md` for consistent PR descriptions