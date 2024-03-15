#!/bin/bash

# Ensure SSH session

if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
  SESSION_TYPE=remote/ssh
else
  case $(ps -o comm= -p "$PPID") in
    sshd|*/sshd) SESSION_TYPE=remote/ssh;;
  esac
fi

if [ "$SESSION_TYPE" = "remote/ssh" ]; then
  echo "Running in a remote SSH session"
else
  echo "Running in a local terminal"
  echo "ERROR: This script is meant to be run on the runpod"
  exit 1
fi

if [[ -z $REMOTE_DIR ]]; then
    echo "REMOTE_DIR is not set, exiting..."
    exit 1
fi

printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
function download() {
    wget -q --show-progress -e dotbytes="${3:-4M}" -O "$2" "$1"
}


### Load development dependencies
apt-get update
apt-get -y install ranger entr vim tmux rsync supervisor git-lfs



# Install AnimateDiff-MotionDirector
if [[ ! -e /workspace/AnimateDiff-MotionDirector ]]; then
    printf "Cloning AnimateDiff-MotionDirector...\n"
    git clone http://github.com/sleexyz/AnimateDiff-MotionDirector.git $REMOTE_DIR
    rm -rf $REMOTE_DIR/models/StableDiffusion
fi
# if [[ ! -e /workspace/AnimateDiff-MotionDirector/models/StableDiffusion ]]; then
#     printf "Cloning StableDiffusion...\n"
#     (cd $REMOTE_DIR; git lfs install; git clone https://huggingface.co/runwayml/stable-diffusion-v1-5 models/StableDiffusion/ --depth 1; git lfs fetch; git lfs checkout)
# fi
(cd $REMOTE_DIR; pip install -r requirements.txt)


MODEL_FILE=$REMOTE_DIR/v3_sd15_mm.ckpt
MODEL_URL=https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_mm.ckpt
if [[ ! -e  $MODEL_FILE ]]; then
    printf "v3_sd15_mm.ckpt not found. Downloading..."
    download $MODEL_URL $MODEL_FILE
fi

MODEL_FILE=$REMOTE_DIR/v3_sd15_adapter.ckpt
MODEL_URL=https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_adapter.ckpt
if [[ ! -e  $MODEL_FILE ]]; then
    printf "v3_sd15_adapter.ckpt not found. Downloading..."
    download $MODEL_URL $MODEL_FILE
fi


echo "*********************"
echo "Provisioning complete"
