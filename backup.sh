#!/bin/bash
set -e

echo "=============================================="
echo "Marina Encrypted Azure Blob Storage Backend"
echo "=============================================="
echo ""
echo "Instance ID: ${MARINA_INSTANCE_ID:-unknown}"
echo ""

# Check if /backup directory is mounted
if [ ! -d "/backup" ]; then
    echo "ERROR: /backup directory not found"
    exit 1
fi

echo "Backup directory: /backup"
echo "Contents of /backup:"
ls -lah /backup/ || true
echo ""

# fail if no ACCOUNT_KEY, ACCOUNT_NAME, CONTAINER_NAME, or BLOB_TIER is set
if [ -z "$ACCOUNT_KEY" ] || [ -z "$ACCOUNT_NAME" ] || [ -z "$CONTAINER_NAME" ] || [ -z "$BLOB_TIER" ]; then
	echo "ERROR: ACCOUNT_KEY, ACCOUNT_NAME, CONTAINER_NAME, and BLOB_TIER environment variables must be set"
	exit 1
fi

# go into the timestamped backup directory (the only one there)
cd /backup/$(ls /backup) || {
    echo "ERROR: Failed to change directory to the backup folder"
    exit 1
}

echo "Starting backup process..."

# run encryption per object in the current directory
for file in *; do
    if [ -f "$file" ]; then
        defaultEncryptionPasswordVariable=ENCRYPTION_PASSWORD_${MARINA_INSTANCE_ID}__
        defaultEncryptionPasswordVariable=${defaultEncryptionPasswordVariable^^}    # uppercase
        defaultEncryptionPasswordVariable=${defaultEncryptionPasswordVariable//-/_} # - to _
        defaultEncryptionPassword=${!defaultEncryptionPasswordVariable}

        specificEncryptionPasswordVariable=ENCRYPTION_PASSWORD_${MARINA_INSTANCE_ID}_$file
        specificEncryptionPasswordVariable=${specificEncryptionPasswordVariable^^}    # uppercase
        specificEncryptionPasswordVariable=${specificEncryptionPasswordVariable//-/_} # - to _
        specificEncryptionPassword=${!specificEncryptionPasswordVariable}

        encryptionPasswordVariable=$defaultEncryptionPasswordVariable
        encryptionPassword=$defaultEncryptionPassword

        if [[ $specificEncryptionPassword ]]; then
            encryptionPasswordVariable=$specificEncryptionPasswordVariable
            encryptionPassword=$specificEncryptionPassword
        fi

        if [[ $encryptionPassword ]]; then
            echo "Encrypting $file with password from $encryptionPasswordVariable:"
            ls -lh "$file"
			tar -cf "$file.tar" "$file"
			gpg -c --cipher-algo aes256 --batch --passphrase "$encryptionPassword" -o "$file.tar.gpg" "$file.tar"
			rm -rf "$file" "$file.tar"
			file="$file.tar.gpg"
        else
            echo "Encryption is required for this backup. Set a password in $defaultEncryptionPasswordVariable or $specificEncryptionPasswordVariable"
            exit 1
        fi
    fi
done

tar -cvf /backup/$MARINA_INSTANCE_ID/archive.tar /backup/$MARINA_INSTANCE_ID/*
ls -lh /backup/$MARINA_INSTANCE_ID/archive.tar

# run uploads
[ "$KEEP_MONTHLY" = 'null' ] && KEEP_MONTHLY=0
[ "$KEEP_YEARLY" = 'null' ] && KEEP_YEARLY=0
keepDays="${KEEP_DAYS:-0}"
keepMonthly="${KEEP_MONTHLY:-0}"
keepYearly="${KEEP_YEARLY:-0}"

# Get the cutoff date for retention
cutoffDate=$(date -d "-$keepDays days" +%s)
cutoffDateFormatted=$(date -d "@$cutoffDate" +%Y-%m-%d)

uploadDate=$(date '+%Y%m%d%H%M')
backupFile="/backup/$MARINA_INSTANCE_ID/archive.tar"
backupName="$MARINA_INSTANCE_ID-$uploadDate.tar"


echo "Uploading backup..."

az storage blob upload \
    --account-key $ACCOUNT_KEY \
    --account-name $ACCOUNT_NAME \
    --container-name $CONTAINER_NAME \
    --name $backupName \
    --file $backupFile

echo "Configuring backup access tier..."

az storage blob set-tier \
    --account-key $ACCOUNT_KEY \
    --account-name $ACCOUNT_NAME \
    --container-name $CONTAINER_NAME \
    --name $backupName \
    --tier $BLOB_TIER

echo "Deleting old backups while keeping all backups of the past $keepDays days; the first backup of the past $keepMonthly months and the first backup of the past $keepYearly years..."

if [[ $keepMonthly -gt 0 || $keepYearly -gt 0 ]]; then
    monthlyCutoffDate=$(date -d "-$keepMonthly months" +%s)
    monthlyCutoffYearMonth=$(date -d "@$monthlyCutoffDate" +%Y-%m)
    yearlyCutoffDate=$(date -d "-$keepYearly years" +%s)
    yearlyCutoffYear=$(date -d "@$yearlyCutoffDate" +%Y)
    declare -A monthlyBlobs
    declare -A yearlyBlobs

    echo "Loading existing blobs..."
    blobs=$(az storage blob list --account-key $ACCOUNT_KEY --account-name $ACCOUNT_NAME --container-name $CONTAINER_NAME --output json --query "[].{name:name, lastModified:properties.lastModified}")

    echo "$blobs" | jq -r '.[] | "\(.name) \(.lastModified)"' | while read -r line; do
        blobName=$(echo $line | awk '{print $1}')
        lastModified=$(echo $line | awk '{print $2}')
        blobDate=$(date -d "$lastModified" +%s)
        yearMonth=$(date -d "$lastModified" "+%Y-%m")
        year=$(date -d "$lastModified" "+%Y")
        if [[ -z "${monthlyBlobs[$yearMonth]}" || -z "${yearlyBlobs[$year]}" ]]; then
            if [[ "${monthlyBlobs[$yearMonth]}"  ||  "$blobDate" -lt "$monthlyCutoffDate" ]]; then
                if [[ "${yearlyBlobs[$year]}" ||  "$blobDate" -lt "$yearlyCutoffDate" ]]; then
                    echo "Deleting blob: $blobName"
                    az storage blob delete --account-key $ACCOUNT_KEY --account-name $ACCOUNT_NAME --container-name $CONTAINER_NAME --name $blobName
                else
                    echo "Keeping blob for $year (more recent than $yearlyCutoffYear): $blobName"
                    yearlyBlobs[$year]=true
                fi
            else
                echo "Keeping blob for $yearMonth (more recent than $monthlyCutoffYearMonth): $blobName"
                monthlyBlobs[$yearMonth]=true
                yearlyBlobs[$year]=true
            fi
        else
            if [[ "$blobDate" -lt "$cutoffDate" ]]; then
                echo "Deleting blob: $blobName"
                az storage blob delete --account-key $ACCOUNT_KEY --account-name $ACCOUNT_NAME --container-name $CONTAINER_NAME --name $blobName
            else
                echo "Keeping blob (more recent than $cutoffDateFormatted): $blobName"
            fi
        fi
    done
else
    az storage blob delete-batch \
        --account-key $ACCOUNT_KEY \
        --account-name $ACCOUNT_NAME \
        --source $CONTAINER_NAME \
        --if-unmodified-since $cutoffDateFormatted
fi

echo "Backup process completed successfully."
