#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

# Installing packages, required for GCE
run_in_chroot $chroot 'curl -L --remote-name-all https://github.com/GoogleCloudPlatform/compute-image-packages/releases/download/1.1.0.1/google-startup-scripts_1.1.0-4_all.deb \
                                                 https://github.com/GoogleCloudPlatform/compute-image-packages/releases/download/1.1.0.1/google-compute-daemon_1.1.0-4_all.deb \
                                                 https://github.com/GoogleCloudPlatform/compute-image-packages/releases/download/1.1.0.1/python-gcimagebundle_1.1.0-3_all.deb'

run_in_chroot $chroot 'dpkg -i --force-all google-startup-scripts_1.1.0-4_all.deb \
                                    google-compute-daemon_1.1.0-4_all.deb \
                                    python-gcimagebundle_1.1.0-3_all.deb'

run_in_chroot $chroot 'apt-get -f -y install'

# Specific ubuntu changes
run_in_chroot $chroot "sed -i 's/sshd/ssh/g' /etc/init/google-accounts-manager-service.conf"
run_in_chroot $chroot "sed -i 's/sshd/ssh/g' /etc/init/google-accounts-manager-task.conf"