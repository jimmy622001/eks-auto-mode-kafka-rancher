# Environment Management

This document explains how to manage different environments (dev/prod) in this Terraform project.

## Environment Structure

- `workspaces/dev/` - Development environment configurations
- `workspaces/prod/` - Production environment configurations
- `locals.tf` - Common configuration for all environments
- `backend.hcl` - Terraform backend configuration

## Setting Up a New Environment

1. **Create a new environment directory**
   ```bash
   mkdir -p workspaces/<environment>
   ```

2. **Copy the example configuration**
   ```bash
   cp workspaces/dev/dev.tfvars.example workspaces/<environment>/<environment>.tfvars
   ```

3. **Update the configuration**
   Edit the `.tfvars` file with your environment-specific values.

## Using an Environment

### Initialize the Backend

```bash
# For development
export TF_WORKSPACE=dev

# For production
export TF_WORKSPACE=prod

# Initialize with the selected workspace
terraform init -backend-config=backend.hcl -reconfigure
```

### Apply Changes

```bash
# Plan changes
terraform plan -var-file="workspaces/$TF_WORKSPACE/$TF_WORKSPACE.tfvars"

# Apply changes
terraform apply -var-file="workspaces/$TF_WORKSPACE/$TF_WORKSPACE.tfvars"
```

## Environment-Specific Configurations

### Development
- Smaller instance types (t3.medium)
- Fewer nodes (1-3)
- Single Kafka replica
- Development domain names

### Production
- Larger instance types (m5.large)
- More nodes (3-6)
- Multiple Kafka replicas (3)
- Production domain names

## Best Practices

1. **Never commit sensitive data** - Add `*.tfvars` to your `.gitignore`
2. **Use workspaces** - Keep state files separate for each environment
3. **Review changes** - Always review the plan before applying in production
4. **Tag resources** - All resources are tagged with their environment for easy identification
