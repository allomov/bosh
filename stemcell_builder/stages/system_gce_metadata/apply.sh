#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

cat >> $chroot/etc/hosts <<EOS
169.254.169.254 metadata.google.internal metadata
EOS
