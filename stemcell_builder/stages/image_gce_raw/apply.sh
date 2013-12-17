#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

qemu-img convert -O raw $work/${stemcell_image_name} $work/disk.raw
