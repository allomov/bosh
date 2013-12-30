#!/usr/bin/env bash
#
# Copyright (c) 2009-2012 VMware, Inc.

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

if [ $DISTRIB_CODENAME == "precise" ]
then
  variant="lts-raring"

  # Headers are needed for open-vm-tools
  pkg_mgr install linux-image-generic-${variant} linux-headers-generic-${variant}
else
  pkg_mgr install linux-image-virtual
fi
