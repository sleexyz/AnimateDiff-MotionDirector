
#!/bin/bash

# DO NOTE use: use sync_loras.sh in ComfyUI repo instead.j

set -ex

source <(pod env)

if [[ -z $REMOTE_DIR ]]; then
    echo "REMOTE_DIR is not set, exiting..."
    exit 1
fi

function push() {
    FILE=$1
    pod ssh -t "'(cd $REMOTE_DIR; mkdir -p $(dirname $FILE))'"
    pod push $FILE $FILE
}

FILE=outputs/2024-03-22/biking_my_video-06-59-17/lora/temporal/6500_biking_temporal_unet.safetensors
push $FILE

FILE=outputs/2024-03-22/biking_my_video-06-59-17/lora/spatial/6500_biking_spatial_unet.safetensors
push $FILE
