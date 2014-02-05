#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

run_in_chroot $chroot "
curl -L --remote-name-all https://github.com/GoogleCloudPlatform/compute-image-packages/releases/download/1.1.0.1/google-startup-scripts_1.1.0-4_all.deb \
                          https://github.com/GoogleCloudPlatform/compute-image-packages/releases/download/1.1.0.1/google-compute-daemon_1.1.0-4_all.deb \
                          https://github.com/GoogleCloudPlatform/compute-image-packages/releases/download/1.1.0.1/python-gcimagebundle_1.1.0-3_all.deb

dpkg -i --force-all google-startup-scripts_1.1.0-4_all.deb \
                    google-compute-daemon_1.1.0-4_all.deb \
                    python-gcimagebundle_1.1.0-3_all.deb

rm google-startup-scripts_1.1.0-4_all.deb \
   google-compute-daemon_1.1.0-4_all.deb \
   python-gcimagebundle_1.1.0-3_all.deb

apt-get -f -y install

sed -i 's/sshd/ssh/g' /etc/init/google-accounts-manager-service.conf
sed -i 's/sshd/ssh/g' /etc/init/google-accounts-manager-task.conf
"