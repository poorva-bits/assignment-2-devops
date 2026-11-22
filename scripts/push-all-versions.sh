#!/usr/bin/env bash
# Build and push one Docker Hub image per Git tag (v1.0 ... v3.0).
# Old tags have no Dockerfile, so the current Dockerfile/.dockerignore are copied in.
# Run from inside the repo on the VM:  DOCKERHUB_USER=yourname ./scripts/push-all-versions.sh
set -euo pipefail
: "${DOCKERHUB_USER:?set DOCKERHUB_USER first}"
cd "$(git rev-parse --show-toplevel)"

cp Dockerfile /tmp/Dockerfile.a2
cp .dockerignore /tmp/dockerignore.a2

for tag in v1.0 v1.1 v1.2 v2.0 v2.1 v3.0; do
  dir=$(mktemp -d)
  git archive "$tag" | tar -x -C "$dir"
  cp /tmp/Dockerfile.a2 "$dir/Dockerfile"
  cp /tmp/dockerignore.a2 "$dir/.dockerignore"
  img="$DOCKERHUB_USER/assignment-2-devops:${tag#v}"
  docker build -t "$img" "$dir"
  docker push "$img"
  rm -rf "$dir"
done

docker tag "$DOCKERHUB_USER/assignment-2-devops:3.0" "$DOCKERHUB_USER/assignment-2-devops:latest"
docker push "$DOCKERHUB_USER/assignment-2-devops:latest"
echo "Done. Check https://hub.docker.com/r/$DOCKERHUB_USER/assignment-2-devops/tags"
