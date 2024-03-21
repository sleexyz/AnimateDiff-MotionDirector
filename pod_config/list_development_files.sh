#!/bin/sh

# 1) Files to trigger reload
# 2) Files to sync

# git ls-files
# git ls-files --others --exclude-standard
find * -type f | grep -v -e '.direnv' -e '.git' -e pod -e '\.ckpt$' -e '\.safetensors$' -e '\.bin$' -e 'outputs/' -e 'videos/'
