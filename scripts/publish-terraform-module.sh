#!/usr/bin/env bash

# shell options
set -eo pipefail
shopt -s globstar nullglob

# requirements
if ! (
  command -v curl && command -v jq && command -v git
) &>/dev/null; then
  echo "[ERROR] curl, jq, and git are required to run this script"
  exit 1
fi
working_directory=$(pwd)
git_directory=$(git rev-parse --show-toplevel)
if [[ "$working_directory" != "$git_directory" ]]; then
  echo "[ERROR] working directory $working_directory should be $git_directory"
  exit 1
fi

### required variables
# GIT_REF: Git ref, like 'refs/tags/0.0.1'
# GITHUB_REPO_NAME: GitHub repo name (organization/repo)
# TERRAFORM_CLOUD_API_TOKEN: owner-level API token for Terraform Cloud
### other variables
# GITHUB_ORG_NAME: name of GitHub user or organization that owns the repo
# TERRAFORM_CLOUD_ORG_NAME: name of Terraform Cloud organization
# TERRAFORM_MODULE_NAME: name of Terraform module as it appears in the registry
# TERRAFORM_MODULE_PROVIDER: Terraform provider required by module
GIT_REF=${GIT_REF:?Variable not set}
case $GIT_REF in
"refs/tags/"*) GIT_TAG=${GIT_REF##"refs/tags/"} ;;
"refs/heads/"*) echo "[ERROR] $GIT_REF is a branch, not a tag" && exit 1 ;;
*) echo "[ERROR] $GIT_REF should be like 'refs/tags/0.0.1'" && exit 1 ;;
esac
GITHUB_REPO_NAME=${GITHUB_REPO_NAME:?Variable not set}
default_github_org_name=$(echo "$GITHUB_REPO_NAME" | cut -d / -f 1)
GITHUB_ORG_NAME=${GITHUB_ORG_NAME:="$default_github_org_name"}
TERRAFORM_CLOUD_API_TOKEN=${TERRAFORM_CLOUD_API_TOKEN:?Variable not set}
TERRAFORM_CLOUD_ORG_NAME=${TERRAFORM_CLOUD_ORG_NAME:="br3ndonland"}
default_module_name_prefix="$GITHUB_ORG_NAME/terraform-aws-"
default_module_name=${GITHUB_REPO_NAME##"$default_module_name_prefix"}
TERRAFORM_MODULE_NAME=${TERRAFORM_MODULE_NAME:="$default_module_name"}
TERRAFORM_MODULE_PROVIDER=${TERRAFORM_MODULE_PROVIDER:="aws"}

base_url="https://app.terraform.io/api/v2"
registry_url="$base_url/organizations/$TERRAFORM_CLOUD_ORG_NAME/registry-modules"
module_path="$TERRAFORM_CLOUD_ORG_NAME/$TERRAFORM_MODULE_NAME"
module_url="$registry_url/private/$module_path/$TERRAFORM_MODULE_PROVIDER"

handle_error_response() {
  local error_response
  error_response=$(echo "$1" | jq '.errors[]?')
  if [ -n "$error_response" ]; then
    echo '[ERROR] error response received'
    echo "$error_response"
    return 1
  fi
}

# check if module exists
get_module_response=$(
  curl -sS \
    --header "Authorization: Bearer $TERRAFORM_CLOUD_API_TOKEN" \
    --header "Content-Type: application/vnd.api+json" \
    "$module_url"
)

# if module not found, create module
module_not_found=$(
  echo "$get_module_response" |
    jq '.errors[]?.status == "404" and .errors[]?.title == "not found"'
)
if [ "$module_not_found" = true ]; then
  create_module_payload=$(
    cat <<JSON
{
  "data": {
    "type": "registry-modules",
    "attributes": {
      "name": "$TERRAFORM_MODULE_NAME",
      "provider": "$TERRAFORM_MODULE_PROVIDER",
      "registry-name": "private"
    }
  }
}
JSON
  )
  echo '[DEBUG] creating module in registry'
  echo "$create_module_payload"
  create_module_response=$(
    curl -sS \
      --header "Authorization: Bearer $TERRAFORM_CLOUD_API_TOKEN" \
      --header "Content-Type: application/vnd.api+json" \
      --data "$create_module_payload" \
      "$registry_url"
  )
  handle_error_response "$create_module_response"
  module_response="$create_module_response"
else
  handle_error_response "$get_module_response"
  module_endpoint=$(echo "$get_module_response" | jq -r '.data.links.self')
  echo "[DEBUG] Terraform module found at $module_endpoint"
  module_response="$get_module_response"
fi

# create module version and upload module archive
module_version=${GIT_TAG##v}
module_versions=$(
  echo "$module_response" |
    jq '[.data.attributes."version-statuses"[].version]'
)
module_version_found=$(
  echo "$module_versions" |
    jq --arg version "$module_version" 'contains([$version])'
)
if [ "$module_version_found" = false ]; then
  # if module version not found, create module version
  create_module_version_payload=$(
    cat <<JSON
{
  "data": {
    "type": "registry-module-versions",
    "attributes": {
      "version": "$module_version"
    }
  }
}
JSON
  )
  echo '[DEBUG] creating module version'
  echo "$create_module_version_payload"
  create_module_version_response=$(
    curl -sS \
      --header "Authorization: Bearer $TERRAFORM_CLOUD_API_TOKEN" \
      --header "Content-Type: application/vnd.api+json" \
      --data "$create_module_version_payload" \
      "$module_url/versions"
  )
  handle_error_response "$create_module_version_response"
  # upload module version
  if [ -n "$create_module_version_response" ]; then
    echo '[DEBUG] parsing upload URL from create module version response'
    upload_url=$(
      echo "$create_module_version_response" | jq -er '.data.links.upload'
    )
    echo '[DEBUG] creating module archive'
    tar zcvf module.tar.gz "./"*
    [ -f module.tar.gz ] && echo '[DEBUG] uploading module archive'
    upload_module_version_response=$(
      curl --retry 10 \
        --header "Content-Type: application/octet-stream" \
        --data-binary @module.tar.gz \
        --request PUT \
        "$upload_url"
    )
    handle_error_response "$upload_module_version_response"
  fi
elif [ "$module_version_found" = true ]; then
  version_status=$(
    echo "$module_response" |
      jq -r --arg version "$module_version" \
        '.data.attributes."version-statuses"[] | select(.version == $version) | .status'
  )
  echo "[ERROR] module version $module_version has status $version_status." \
    "If a module version already exists, but the status is pending," \
    "it may not be possible to get an upload URL." \
    "Version should be deleted and re-created."
  exit 1
else
  echo "[ERROR] error handling version $module_version. Most recent response:"
  echo "$module_response"
  exit 1
fi
