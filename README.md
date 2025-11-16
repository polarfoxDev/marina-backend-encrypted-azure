# Marina Azure Blob Storage Backend (Encrypted)

Custom encrypted backup backend for [Marina](https://github.com/polarfoxDev/marina) that encrypts backups with GPG and uploads them to Azure Blob Storage.

This backend is designed to work with Marina's [custom backup backend system](https://github.com/polarfoxDev/marina?tab=readme-ov-file#custom-backup-backends).

## Project Status

> [!CAUTION]
> This backend is still in **early beta** and untested. Use at your own risk. Feedback and contributions are welcome!

## Features

- 🔒 **GPG Encryption**: Encrypts backup files using AES-256 before upload
- ☁️ **Azure Blob Storage**: Stores encrypted backups in Azure Blob Storage
- 📦 **Automatic Archiving**: Creates compressed tar archives of backups
- 🗄️ **Flexible Retention**: Supports daily, monthly, and yearly retention policies
- 🔑 **Per-Instance or Per-Target Encryption**: Configurable encryption passwords
- 🏷️ **Blob Tier Management**: Configurable Azure Blob storage tiers (Hot, Cool, Archive)

## Prerequisites

- Docker
- Azure Storage Account with Blob Storage
- Marina instance

## Environment Variables

### Required

| Variable         | Description                                  |
| ---------------- | -------------------------------------------- |
| `ACCOUNT_KEY`    | Azure Storage Account access key             |
| `ACCOUNT_NAME`   | Azure Storage Account name                   |
| `CONTAINER_NAME` | Azure Blob Storage container name            |
| `BLOB_TIER`      | Azure Blob storage tier (Hot, Cool, Archive) |

### Encryption Passwords

Encryption is **required** for all backups. You must set at least one of:

- `ENCRYPTION_PASSWORD_{INSTANCE_ID}__` - Default password for all targets in an instance
- `ENCRYPTION_PASSWORD_{INSTANCE_ID}_{TARGET}` - Specific password for individual targets

**Note**: Instance ID and target are automatically uppercased and hyphens are converted to underscores in variable names.

**Example**: For instance `cool-app` and target `my-database`:

```bash
ENCRYPTION_PASSWORD_COOL_APP__=defaultpass123
ENCRYPTION_PASSWORD_COOL_APP_MY_DATABASE=specificpass456
```

### Retention Policy

| Variable       | Default | Description                                         |
| -------------- | ------- | --------------------------------------------------- |
| `KEEP_DAYS`    | 0       | Number of days to keep all backups                  |
| `KEEP_MONTHLY` | 0       | Number of months to keep first backup of each month |
| `KEEP_YEARLY`  | 0       | Number of years to keep first backup of each year   |

## Usage with Marina

### 1. Build the Docker Image

```bash
docker build -t marina-backend-encrypted-azure .
```

### 2. Configure Marina

Add this backend to your Marina configuration. The backend expects the `/backup` directory to be mounted from Marina.

Example `config.yml` configuration:

```yaml
instances:
  - id: cool-app
    customImage: polarfoxdev/marina-backend-encrypted-azure
    schedule: "0 3 * * *"
    env:
      ACCOUNT_KEY: ${AZURE_ACCOUNT_KEY}
      ACCOUNT_NAME: ${AZURE_ACCOUNT_NAME}
      CONTAINER_NAME: ${AZURE_CONTAINER_NAME}
      BLOB_TIER: Cool
      MARINA_INSTANCE_ID: cool-app
      ENCRYPTION_PASSWORD_COOL_APP__: ${ENCRYPTION_PASSWORD}
      KEEP_DAYS: 7
      KEEP_MONTHLY: 6
      KEEP_YEARLY: 3
```

For complete Marina setup instructions, see the [Marina documentation](https://github.com/polarfoxDev/marina?tab=readme-ov-file#custom-backup-backends).

## How It Works

1. **Backup Creation**: Marina creates backup files in `/backup/{timestamp}/`
2. **Encryption**: Each target directory is tarred, then encrypted with GPG using AES-256
3. **Archiving**: All encrypted files are bundled into a single tar archive
4. **Upload**: Archive is uploaded to Azure Blob Storage with timestamp
5. **Tier Configuration**: Blob storage tier is set according to `BLOB_TIER`
6. **Cleanup**: Old backups are deleted based on retention policy

## Retention Policy Details

The retention policy works as follows:

- **Keep Days**: All backups within this period are kept
- **Keep Monthly**: Beyond KEEP_DAYS, the first backup of each month is kept
- **Keep Yearly**: Beyond KEEP_MONTHLY, the first backup of each year is kept

**Example**: With `KEEP_DAYS=7`, `KEEP_MONTHLY=6`, `KEEP_YEARLY=3`:

- All backups from the last 7 days are kept
- For months 1-6 ago, only the first backup of each month is kept
- For years 1-3 ago, only the first backup of each year is kept
- All other backups are deleted

## Security Considerations

- Store encryption passwords securely (use Docker secrets or environment encryption)
- Use Azure Blob Storage with appropriate access controls
- Consider using Azure Storage immutable policies for compliance
- Regularly test backup restoration procedures
- Store decryption passwords in a secure location separate from backups

## Decryption Process

To restore a backup:

1. Download the archive from Azure Blob Storage
2. Extract the tar archive: `tar -xvf archive.tar`
3. Decrypt each file: `gpg -d --batch --passphrase "YOUR_PASSWORD" file.tar.gpg > file.tar`
4. Extract the tar file: `tar -xf file.tar`

## Troubleshooting

### "ERROR: ACCOUNT_KEY, ACCOUNT_NAME, CONTAINER_NAME, and BLOB_TIER environment variables must be set"

One or more required Azure configuration variables are missing.

### "Encryption is required for this backup"

No encryption password is set. Define `ENCRYPTION_PASSWORD_{INSTANCE_ID}__` or a target-specific password.

## License

See [LICENSE](LICENSE) file for details.

## Contributing

Issues and pull requests are welcome!

## Related Projects

- [Marina](https://github.com/polarfoxDev/marina) - The main backup orchestration system
