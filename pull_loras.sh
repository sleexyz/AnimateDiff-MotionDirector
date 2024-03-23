#!/bin/bash


function pull() {
    FILE=$1
    if [[ ! -e  $FILE ]]; then
        printf "$FILE not found. Downloading..."
        mkdir -p $(dirname $FILE)
        pod pull $FILE $FILE
    fi
}

FILE=outputs/2024-03-22/biking_my_video-06-59-17/lora/temporal/6500_biking_temporal_unet.safetensors
pull $FILE

FILE=outputs/2024-03-22/biking_my_video-06-59-17/lora/spatial/6500_biking_spatial_unet.safetensors
pull $FILE