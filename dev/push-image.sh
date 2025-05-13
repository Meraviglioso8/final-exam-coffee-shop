#!/bin/bash

DOCKER_HUB_USERNAME="meraviglioso8"  
TARGET_REGISTRY="docker.io" 
DOCKER_IMAGES=(
  "cuongopswat/go-coffeeshop-web"
  "cuongopswat/go-coffeeshop-proxy"
  "cuongopswat/go-coffeeshop-barista"
  "cuongopswat/go-coffeeshop-kitchen"
  "cuongopswat/go-coffeeshop-counter"
  "cuongopswat/go-coffeeshop-product"
  "postgres:14-alpine"
  "rabbitmq:3.11-management-alpine"
)

pull_and_push_image() {
  local image=$1
  # Remove content before '/' and after the first ':' (if any)
  local image_name=$(echo $image | sed 's/^[^/]*\///;s/:.*//')
  local target_image="$DOCKER_HUB_USERNAME/$image_name"
  
  echo "Pulling image: $TARGET_REGISTRY/$image"
  docker pull "$TARGET_REGISTRY/$image"

  local version_tag=$(git rev-parse --short HEAD) 
  echo "Tagging image: $TARGET_REGISTRY/$image -> $target_image:$version_tag"
  docker tag "$TARGET_REGISTRY/$image" "$target_image:$version_tag"

  echo "Pushing image to Docker Hub with version tag: $target_image:$version_tag"
  docker push "$target_image:$version_tag"

  echo "Tagging image with 'latest': $TARGET_REGISTRY/$image -> $target_image:latest"
  docker tag "$TARGET_REGISTRY/$image" "$target_image:latest"

  echo "Pushing image to Docker Hub with 'latest' tag: $target_image:latest"
  docker push "$target_image:latest"

}

for image in "${DOCKER_IMAGES[@]}"; do
  pull_and_push_image "$image"
done

echo "Done"
