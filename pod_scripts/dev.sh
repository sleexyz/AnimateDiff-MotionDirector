#!/bin/bash

if [[ -z $SSH_CMD ]]; then
  echo "SSH_CMD is not set"
  exit 1
fi

function cleanup {
  echo "Cleanup"
}

trap cleanup EXIT

"$(dirname $0)/list_backend_files.sh" | entr -crs "$(dirname $0)/sync.sh"
