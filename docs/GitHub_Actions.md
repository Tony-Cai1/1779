# GitHub Actions CI/CD Setup

This document describes the GitHub Actions CI/CD pipeline configuration for the Library Management System (LMS) project.

## Overview

The CI/CD pipeline automates:
- **Testing**: Runs linting and tests on every push and pull request
- **Building**: Builds Docker images on pushes to main/master branches
- **Pushing**: Pushes Docker images to DigitalOcean Container Registry (DOCR)
- **Tagging**: Automatically tags images with branch names, commit SHAs, and semantic versions

## Workflow File

The workflow is defined in `.github/workflows/ci.yml` and triggers on:
- **Push** to `main`, `master`, or `develop` branches
- **Pull requests** to `main`, `master`, or `develop` branches
- **Tags** starting with `v` (e.g., `v1.0.0`)

## Prerequisites

### 1. DigitalOcean Container Registry

You need a DigitalOcean Container Registry set up. If you haven't created one:

```bash
# Create a registry (registry names must be globally unique)
doctl registry create lms-registry-1779

# Get your registry name
doctl registry get
```

### 2. GitHub Secrets

You need to configure the following secrets in your GitHub repository:

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add:

#### Required Secrets

- **`DO_REGISTRY_USERNAME`**: Your DigitalOcean registry username
  - Get it from: `doctl registry get --format Username`
  - Or use your DigitalOcean API token

- **`DO_REGISTRY_TOKEN`**: Your DigitalOcean API token
  - Generate at: https://cloud.digitalocean.com/account/api/tokens
  - The token needs `read` and `write` scopes for Container Registry

#### Getting Your Registry Credentials

```bash
# Option 1: Use DigitalOcean API token
# Generate token at: https://cloud.digitalocean.com/account/api/tokens
# Use the token as both username and password

# Option 2: Get registry-specific credentials
doctl registry login
# This will prompt for credentials, but for GitHub Actions, use API token
```

**Note**: For GitHub Actions, you can use your DigitalOcean API token as both the username and password for registry authentication.

## Workflow Jobs

### 1. Test Job

Runs on every push and pull request:

- **Checkout code**: Checks out the repository
- **Set up Python**: Installs Python 3.10 with pip caching
- **Install dependencies**: Installs project dependencies and test tools
- **Run linting**: Runs flake8 and black (formatting check)
- **Run tests**: Runs pytest if test files exist (fails gracefully if no tests)

**Note**: The test job will pass even if no test files exist. Add tests to `tests/` directory to enable actual testing.

### 2. Build and Push Job

Runs only on pushes to `main` or `master` branches (not on pull requests):

- **Checkout code**: Checks out the repository
- **Set up Docker Buildx**: Sets up Docker buildx for multi-platform builds
- **Log in to DOCR**: Authenticates with DigitalOcean Container Registry
- **Extract metadata**: Generates image tags based on:
  - Branch name (e.g., `main`, `develop`)
  - Commit SHA (e.g., `main-abc1234`)
  - Semantic version tags (e.g., `v1.0.0`, `1.0`)
  - `latest` tag for default branch
- **Build and push**: Builds Docker image and pushes to registry with all tags
- **Cache**: Uses GitHub Actions cache for faster builds

### 3. Notify Job (Optional)

Runs only on failure to notify about CI/CD failures. Currently just logs a message, but you can extend it to send notifications via:
- Slack
- Email
- Microsoft Teams
- Discord
- etc.

## Image Tagging Strategy

The workflow automatically tags images with:

1. **Branch name**: `main`, `develop`, etc.
2. **Commit SHA**: `main-abc1234` (first 7 characters)
3. **Semantic version**: `v1.0.0`, `1.0.0`, `1.0` (if tag starts with `v`)
4. **Latest**: `latest` (only for default branch)

Example tags for a push to `main` branch:
- `registry.digitalocean.com/lms-registry-1779/lms-api:main`
- `registry.digitalocean.com/lms-registry-1779/lms-api:main-abc1234`
- `registry.digitalocean.com/lms-registry-1779/lms-api:latest`

Example tags for a tag `v1.2.3`:
- `registry.digitalocean.com/lms-registry-1779/lms-api:v1.2.3`
- `registry.digitalocean.com/lms-registry-1779/lms-api:1.2.3`
- `registry.digitalocean.com/lms-registry-1779/lms-api:1.2`

## Customization

### Update Registry Name

If your registry name is different, update the workflow file:

```yaml
env:
  REGISTRY: registry.digitalocean.com
  REGISTRY_NAME: your-registry-name  # Change this
  IMAGE_NAME: lms-api
```

### Add More Test Steps

To add actual tests:

1. Create a `tests/` directory
2. Add test files (e.g., `test_main.py`)
3. The workflow will automatically discover and run them

Example test file structure:
```
tests/
  __init__.py
  test_main.py
  test_auth.py
  test_crud.py
```

### Change Trigger Branches

To trigger on different branches, update the `on` section:

```yaml
on:
  push:
    branches:
      - main
      - your-branch
  pull_request:
    branches:
      - main
```

### Enable Notifications

To add Slack notifications on failure:

```yaml
- name: Notify Slack on Failure
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
    payload: |
      {
        "text": "CI/CD pipeline failed for ${{ github.repository }}"
      }
```

## Viewing Workflow Runs

1. Go to your repository on GitHub
2. Click on the **Actions** tab
3. Select a workflow run to see detailed logs
4. Click on individual jobs to see step-by-step execution

## Troubleshooting

### Build Fails with Authentication Error

**Problem**: `unauthorized: authentication required`

**Solution**:
1. Verify `DO_REGISTRY_USERNAME` and `DO_REGISTRY_TOKEN` secrets are set correctly
2. Ensure the API token has Container Registry read/write permissions
3. Test registry login locally:
   ```bash
   echo $DO_API_TOKEN | docker login registry.digitalocean.com -u $DO_API_TOKEN --password-stdin
   ```

### Image Not Found in Registry

**Problem**: Image doesn't appear in DOCR after push

**Solution**:
1. Check workflow logs for push step
2. Verify registry name matches: `doctl registry get`
3. List images: `doctl registry repository list-tags lms-api`

### Tests Fail but No Test Files

**Problem**: Test job fails even though you don't have tests

**Solution**: The workflow uses `continue-on-error: true` for tests, so it won't fail the pipeline. If you want to add tests, create a `tests/` directory with test files.

### Build Takes Too Long

**Problem**: Docker builds are slow

**Solution**: The workflow uses GitHub Actions cache (`cache-from` and `cache-to`). Subsequent builds will be faster. You can also:
- Use Docker layer caching
- Optimize your Dockerfile
- Use multi-stage builds

## Best Practices

1. **Never commit secrets**: Always use GitHub Secrets
2. **Tag releases**: Use semantic version tags (`v1.0.0`) for releases
3. **Test before merge**: Ensure tests pass before merging PRs
4. **Monitor builds**: Check the Actions tab regularly
5. **Update dependencies**: Keep GitHub Actions versions updated
6. **Use branch protection**: Require CI to pass before merging

## Next Steps

After setting up GitHub Actions:

1. **Set up ArgoCD**: See [ArgoCD.md](ArgoCD.md) for continuous deployment
2. **Configure branch protection**: Require CI to pass before merging
3. **Add more tests**: Create comprehensive test suite
4. **Set up notifications**: Configure Slack/email notifications
5. **Monitor builds**: Set up dashboards for CI/CD metrics

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [DigitalOcean Container Registry](https://docs.digitalocean.com/products/container-registry/)
- [Docker Buildx](https://docs.docker.com/buildx/)
- [Semantic Versioning](https://semver.org/)

