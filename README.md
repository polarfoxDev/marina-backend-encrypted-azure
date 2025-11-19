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

| Variable              | Description                                  |
| --------------------- | -------------------------------------------- |
| `ACCOUNT_KEY`         | Azure Storage Account access key             |
| `ACCOUNT_NAME`        | Azure Storage Account name                   |
| `CONTAINER_NAME`      | Azure Blob Storage container name            |
| `BLOB_TIER`           | Azure Blob storage tier (Hot, Cool, Archive) |
| `MARINA_INSTANCE_ID`  | Unique identifier for the Marina instance    |
| `ENCRYPTION_PASSWORD` | Password for GPG encryption (required)       |

### Retention Policy

| Variable       | Default | Description                                         |
| -------------- | ------- | --------------------------------------------------- |
| `KEEP_DAYS`    | 0       | Number of days to keep all backups                  |
| `KEEP_MONTHLY` | 0       | Number of months to keep first backup of each month |
| `KEEP_YEARLY`  | 0       | Number of years to keep first backup of each year   |

If all retention variables are set to `0`, no backups will be deleted.

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
      MARINA_INSTANCE_ID: my-app-prod
      ENCRYPTION_PASSWORD: ${ENCRYPTION_PASSWORD}
      KEEP_DAYS: 7
      KEEP_MONTHLY: 6
      KEEP_YEARLY: 3
```

For complete Marina setup instructions, see the [Marina documentation](https://github.com/polarfoxDev/marina?tab=readme-ov-file#custom-backup-backends).

## How It Works

1. **Backup Creation**: Marina creates backup files in `/backup/{timestamp}/`
2. **Archiving**: All backup files are bundled into a single tar archive
3. **Encryption**: The tar archive is encrypted with GPG using AES-256
4. **Upload**: Encrypted archive is uploaded to Azure Blob Storage with timestamp
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

1. Download the encrypted archive from Azure Blob Storage
2. Decrypt the archive: `gpg -d --batch --passphrase "YOUR_PASSWORD" archive.tar.gpg > archive.tar`
3. Extract the tar archive: `tar -xvf archive.tar`

## Troubleshooting

### "ERROR: ACCOUNT_KEY, ACCOUNT_NAME, CONTAINER_NAME, and BLOB_TIER environment variables must be set"

One or more required Azure configuration variables are missing.

### "Encryption is required for this backup"

The `ENCRYPTION_PASSWORD` environment variable is not set.

## License

See [LICENSE](LICENSE) file for details.

## Contributing

Issues and pull requests are welcome!

## Related Projects

- [Marina](https://github.com/polarfoxDev/marina) - The main backup orchestration system
