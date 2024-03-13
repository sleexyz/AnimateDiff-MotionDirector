#!/bin/sh

# if --setup

if [ "$1" = "setup" ]; then
    bun run pod/setup_remote.ts $@
    exit
fi

if [ "$1" = "dev" ]; then
    SSH_CMD=$(cat .ssh_cmd) ./pod_scripts/dev.sh $@
    exit
fi

if [ "$1" = "ssh" ]; then
    SSH_CMD=$(cat .ssh_cmd)
    $SSH_CMD ${@:2}
    exit
fi
