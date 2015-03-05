#Sensu

FROM fedora:21

MAINTAINER Yury Kavaliou <Yury_Kavaliou@epam.com>

COPY ./files/sensu.repo /etc/yum.repos.d/sensu.repo
RUN yum install -y sensu \
	ruby \
	initscripts \
	supervisor \
	&& gem install sensu-plugin

COPY ./files/plugins/ /etc/sensu/plugins/
COPY ./files/sensu-init.sh /etc/sensu/sensu-init.sh

RUN chmod 700 /etc/sensu/sensu-init.sh

# supervisord
COPY ./files/supervisord.conf /etc/supervisord.conf

ENTRYPOINT [ "/bin/bash", "/etc/sensu/sensu-init.sh" ]