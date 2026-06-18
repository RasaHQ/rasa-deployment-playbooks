#!/usr/bin/env bash
set -e

# Build and push the A2A contact assistant action server image to ECR.
# Requires IAM permissions for ecr:* on the target repository (create, login, push).
# Run after sourcing aws/setup/environment-variables.sh and configuring
# ACTION_SERVER_IMAGE_REPO / ACTION_SERVER_IMAGE_TAG.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../../../utils/common.sh"

validate_variables AWS_PROFILE AWS_REGION ACTION_SERVER_IMAGE_REPO ACTION_SERVER_IMAGE_TAG

if [[ -z "${A2A_SERVER_AGENT_DIR:-}" ]]; then
  A2A_SERVER_AGENT_DIR="$(cd "$SCRIPT_DIR/../../../../qa-bots/a2a-server-agent" && pwd)"
fi

if [[ ! -d "$A2A_SERVER_AGENT_DIR/actions" ]]; then
  print_error "A2A bot actions/ not found at: $A2A_SERVER_AGENT_DIR"
  print_error "Set A2A_SERVER_AGENT_DIR to the qa-bots/a2a-server-agent checkout and re-run."
  exit 1
fi

if [[ ! -d "$A2A_SERVER_AGENT_DIR/db" ]]; then
  print_error "A2A bot db/ not found at: $A2A_SERVER_AGENT_DIR"
  exit 1
fi

print_info "Using bot source:       $A2A_SERVER_AGENT_DIR"
print_info "Image:                  $ACTION_SERVER_IMAGE_REPO:$ACTION_SERVER_IMAGE_TAG"

REPO_NAME="${ACTION_SERVER_IMAGE_REPO##*/}"
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

print_info "Ensuring ECR repository exists: $REPO_NAME"
if ! aws ecr describe-repositories --repository-names "$REPO_NAME" >/dev/null 2>&1; then
  aws ecr create-repository --repository-name "$REPO_NAME" >/dev/null
  print_info "Created ECR repository: $REPO_NAME"
else
  print_info "ECR repository already exists: $REPO_NAME"
fi

print_info "Logging in to ECR: $ECR_REGISTRY"
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

# EKS nodes in this playbook use x86_64 (m6i). Build for linux/amd64 even on Apple Silicon.
BUILD_PLATFORM="${BUILD_PLATFORM:-linux/amd64}"
print_info "Building action server image for platform: $BUILD_PLATFORM"
docker buildx build \
  --platform "$BUILD_PLATFORM" \
  -f "$SCRIPT_DIR/Dockerfile.actions" \
  -t "${ACTION_SERVER_IMAGE_REPO}:${ACTION_SERVER_IMAGE_TAG}" \
  --push \
  "$A2A_SERVER_AGENT_DIR"

print_info "Action server image pushed successfully."
print_info "Ensure ACTION_SERVER_IMAGE_REPO matches the pushed URI, then run setup-assistant.sh."
