FROM centos:7

# Install Ansible Runner
RUN yum -y update && yum -y install epel-release  && \
    yum -y install ansible python-psutil python-pip bubblewrap bzip2 python-crypto openssh \
    openssh-clients
RUN pip install python-memcached wheel pexpect psutil python-daemon

RUN curl https://copr.fedorainfracloud.org/coprs/g/ansible-service-broker/ansible-service-broker-latest/repo/epel-7/group_ansible-service-broker-ansible-service-broker-latest-epel-7.repo -o /etc/yum.repos.d/asb.repo
RUN yum -y install epel-release centos-release-openshift-origin \
    && yum -y install --setopt=tsflags=nodocs origin-clients python-openshift ansible ansible-kubernetes-modules ansible-asb-modules apb-base-scripts \
    && yum clean all

ADD dist/ansible_runner-1.0-py2.py3-none-any.whl /ansible_runner-1.0-py2.py3-none-any.whl
RUN pip install /ansible_runner-1.0-py2.py3-none-any.whl

RUN localedef -c -i en_US -f UTF-8 en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ADD https://github.com/krallin/tini/releases/download/v0.14.0/tini /tini
RUN chmod +x /tini

ENV USER_NAME=apb \
    USER_UID=1001 \
    BASE_DIR=/opt/apb
ENV HOME=${BASE_DIR}
ADD demo/project /opt/apb/runner/project
ADD demo/env /opt/apb/runner/env
ADD demo/inventory /runner/inventory
#VOLUME /opt/apb/runner/inventory
#VOLUME /opt/apb/runner/project
#VOLUME /opt/apb/runner/artifacts
RUN mkdir -p /usr/share/ansible/openshift \
              /etc/ansible /opt/ansible \
              ${BASE_DIR}/{etc,runner,.kube,.ansible/tmp} \
              && useradd -u ${USER_UID} -r -g 0 -M -d ${BASE_DIR} -b ${BASE_DIR} -s /sbin/nologin -c "apb user" ${USER_NAME} \
              && chown -R ${USER_NAME}:0 /opt/{ansible,apb} \
              && chmod -R g=u /opt/{ansible,apb} /etc/passwd

WORKDIR /opt/apb
ENV RUNNER_BASE_COMMAND=ansible-playbook
ADD entrypoint.sh /usr/bin/


ENTRYPOINT ["entrypoint.sh"]

