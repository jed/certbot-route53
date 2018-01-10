#!/usr/bin/env bash

MYSELF="$(cd $(dirname "$0") && pwd)/$(basename $0)"

if [ -z $CERTBOT_DOMAIN ]; then
  mkdir -p $PWD/letsencrypt

  certbot certonly \
    --non-interactive \
    --manual \
    --manual-auth-hook "$MYSELF" \
    --manual-cleanup-hook "$MYSELF" \
    --preferred-challenge dns \
    --config-dir $PWD/letsencrypt \
    --work-dir $PWD/letsencrypt \
    --logs-dir $PWD/letsencrypt \
    $@

else
  [[ $CERTBOT_AUTH_OUTPUT ]] && ACTION="DELETE" || ACTION="UPSERT"

  printf -v QUERY 'HostedZones[?Name == `%s.`]|[?Config.Privatezone != `false`].Id' "${CERTBOT_DOMAIN}"

  HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query $QUERY --output text)

  if [ -z $HOSTED_ZONE_ID ]; then
    echo "No hosted zone found that matches $CERTBOT_DOMAIN"
    exit 1
  fi

  aws route53 wait resource-record-sets-changed --id $(
    aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --query ChangeInfo.Id --output text \
    --change-batch "{
      \"Changes\": [{
        \"Action\": \"$ACTION\",
        \"ResourceRecordSet\": {
          \"Name\": \"_acme-challenge.$CERTBOT_DOMAIN.\",
          \"ResourceRecords\": [{\"Value\": \"\\\"$CERTBOT_VALIDATION\\\"\"}],
          \"Type\": \"TXT\",
          \"TTL\": 30
        }
      }]
    }"
  )

  echo 1
fi
