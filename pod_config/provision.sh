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
sudo apt-get update
sudo apt-get -y install ranger entr vim tmux rsync supervisor git-lfs



# Install AnimateDiff-MotionDirector
if [[ ! -e $REMOTE_DIR ]]; then
    printf "Cloning AnimateDiff-MotionDirector...\n"
    git clone http://github.com/sleexyz/AnimateDiff-MotionDirector.git $REMOTE_DIR
    rm -rf $REMOTE_DIR/models/StableDiffusion
fi

if [[ ! -e $REMOTE_DIR/models/StableDiffusion ]]; then
    printf "Cloning StableDiffusion...\n"
    (cd $REMOTE_DIR; git lfs install; git clone https://huggingface.co/runwayml/stable-diffusion-v1-5 models/StableDiffusion/ --depth 1; git lfs fetch; git lfs checkout)
fi


CONDA_BIN=$HOME/miniconda3/bin
export PATH=$CONDA_BIN:$PATH
CONDA=$CONDA_BIN/conda

if $CONDA env list | grep -q "$REMOTE_DIR"; then
    echo "base already exists"
else 
    $CONDA create -y -p $REMOTE_DIR/venv python=3.10 -c conda-forge
fi
source $CONDA_BIN/activate $REMOTE_DIR/venv

source activate $REMOTE_DIR/venv
(cd $REMOTE_DIR; pip install -r requirements.txt)

# install cloudflared
if [[ ! -e /usr/local/bin/cloudflared ]]; then
    mkdir -p /tmp/cloudflared
    (cd /tmp/cloudflared; wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb; sudo dpkg -i cloudflared-linux-amd64.deb)
fi

MODEL_FILE=$REMOTE_DIR/models/Motion_Module/v3_sd15_mm.ckpt
MODEL_URL=https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_mm.ckpt
if [[ ! -e  $MODEL_FILE ]]; then
    printf "v3_sd15_mm.ckpt not found. Downloading..."
    download $MODEL_URL $MODEL_FILE
fi

MODEL_FILE=$REMOTE_DIR/models/Motion_Module/v3_sd15_adapter.ckpt
MODEL_URL=https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_adapter.ckpt
if [[ ! -e  $MODEL_FILE ]]; then
    printf "v3_sd15_adapter.ckpt not found. Downloading..."
    download $MODEL_URL $MODEL_FILE
fi

MODEL_FILE=$REMOTE_DIR/models/MotionLoRA/260_cseti_8890531_drone-forward-mv2_r64_w576_h384_fr16.safetensors
MODEL_URL=https://huggingface.co/Cseti/AD_Motion_LORAs/resolve/main/260_cseti_8890531_drone-forward-mv2_r64_w576_h384_fr16.safetensors
if [[ ! -e  $MODEL_FILE ]]; then
    printf "260_cseti_8890531_drone-forward-mv2_r64_w576_h384_fr16.safetensors not found. Downloading..."
    download $MODEL_URL $MODEL_FILE
fi

# Error if $CLOUDFLARE_DEMO_KEY is not set
if [[ -z $CLOUDFLARE_DEMO_KEY ]]; then
    echo "CLOUDFLARE_DEMO_KEY is not set"
    exit 1
fi

mkdir -p $REMOTE_DIR/videos

cat << EOF > $REMOTE_ROOT/supervisord-$WORKSPACE_NAME.fragment.conf
[program:jupyter]
user=ubuntu
chown=ubuntu:ubuntu
command=/bin/bash -c "(source $CONDA_BIN/activate $REMOTE_DIR/venv; cd $REMOTE_DIR; kill \$(lsof -t -i:8875); JUPYTER_CONFIG_DIR=$REMOTE_DIR/jupyter jupyter notebook --ip 0.0.0.0 --no-browser --port 8875 --allow-root)"
stopasgroup = true
killasgroup = true
autostart=true
autorestart=true
redirect_stderr=true
stderr_logfile=$REMOTE_ROOT/logs/jupyter.err.log
stdout_logfile=$REMOTE_ROOT/logs/jupyter.out.log

[program:cloudflared_jupyter]
user=ubuntu
chown=ubuntu:ubuntu
command=/usr/local/bin/cloudflared tunnel run --url http://localhost:8875 --token $CLOUDFLARE_DEMO_KEY
autostart=true
autorestart=true
redirect_stderr=true
stderr_logfile=$REMOTE_ROOT/logs/cloudflared_jupyter.err.log
stdout_logfile=$REMOTE_ROOT/logs/cloudflared_jupyter.out.log

EOF

echo "*********************"
echo "Project provisioning complete"
echo "*********************"

