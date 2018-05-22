#!/bin/bash

set -x

# Work-Around
# The OpenShift's s2i (source to image) requires that no ENTRYPOINT exist
# for any of the s2i builder base images.  Our 's2i-apb' builder uses the
# apb-base as it's base image.  But since the apb-base defines its own
# entrypoint.sh, it is not compatible with the current source-to-image.
#
# The below work-around checks if the entrypoint was called within the
# s2i-apb's 'assemble' script process. If so, it skips the rest of the steps
# which are APB run-time specific.
#
# Details of the issue in the link below:
# https://github.com/openshift/source-to-image/issues/475
#
if [[ $@ == *"s2i/assemble"* ]]; then
  echo "---> Performing S2I build... Skipping server startup"
  exec "$@"
  exit $?
fi

ROLE=$2
ACTION=$1
echo $3 | sed 's/\([^ ]* [^ ]*\) /\1\n/g' >> /opt/apb/runner/env/extravars
if [ -z $1 ]
then
  echo "No Role specified"
  exit
fi
if [ -z $2 ]
then
  echo "No action specified"
  exit
fi
shift
playbooks=/opt/apb/actions
CREDS="/var/tmp/bind-creds"
TEST_RESULT="/var/tmp/test-result"

if ! whoami &> /dev/null; then
  if [ -w /etc/passwd ]; then
    echo "${USER_NAME:-apb}:x:$(id -u):0:${USER_NAME:-apb} user:${HOME}:/sbin/nologin" >> /etc/passwd
  fi
fi

set +x

SECRETS_DIR=/etc/apb-secrets
mounted_secrets=$(ls $SECRETS_DIR)

extra_args=""
if [[ ! -z "$mounted_secrets" ]] ; then

    echo '---' > /tmp/secrets

    for key in ${mounted_secrets} ; do
      for file in $(ls ${SECRETS_DIR}/${key}/..data); do
        echo "$file: $(cat ${SECRETS_DIR}/${key}/..data/${file})" >> /tmp/secrets
      done
    done
    extra_args='--extra-vars no_log=true --extra-vars @/tmp/secrets'
fi
set -x

ansible-galaxy install $ROLE -p /opt/apb/runner/project
whoami
id
cat /opt/apb/runner/env/extravars
cat << EOF > /opt/apb/runner/project/${ACTION}.yml
---
- hosts: localhost
  connection: local
  vars:
    apb_action: ${ACTION}
  roles:
    - role: ansible.kubernetes-modules
    - role: ${ROLE}
EOF

EXIT_CODE=$?

set +ex
rm -f /tmp/secrets
set -ex

if [ -f $TEST_RESULT ]; then
   test-retrieval-init
fi

RUNNER_PLAYBOOK=$ACTION.yml ansible-runner run /opt/apb/runner

exit $EXIT_CODE
