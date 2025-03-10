# This script fetches a base RHEL VM image needed to build the Kata peer-PODs VM
# image.

if ! type -p jq 2> /dev/null; then 
    echo 1>&2 'Error: this script requires `jq` to work'
    exit 1
fi

OS_VERSION=9.5
REDHAT_OFFLINE_TOKEN="${REDHAT_OFFLINE_TOKEN:?Please generate the REDHAT_OFFLINE_TOKEN from https://access.redhat.com/management/api}"
TOKEN_GENERATOR_URI=https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token
IMAGES_URI=https://api.access.redhat.com/management/v1/images/rhel/$OS_VERSION/s390x

filename="rhel-$OS_VERSION-s390x-kvm.qcow2" 

token=$(curl $TOKEN_GENERATOR_URI \
	-d grant_type=refresh_token -d client_id=rhsm-api \
    -d refresh_token=$REDHAT_OFFLINE_TOKEN \
    | jq --raw-output .access_token)

images=$(curl -X 'GET' $IMAGES_URI \
	-H 'accept: application/json' -H "Authorization: Bearer $token" | jq )

download_href=$(echo $images | jq -r --arg fn "$filename" '.body[] | select(.filename == $fn) | .downloadHref')

download_url=$(curl -X 'GET' ${download_href} \
	-H "Authorization: Bearer $token" -H 'accept: application/json' | jq -r .body.href )

curl -X GET $download_url -H "Authorization: Bearer $token" \
    --output rhel-$OS_VERSION-s390x-kvm.qcow2
