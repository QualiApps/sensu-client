#Sensu

FROM fedora:21

MAINTAINER Yury Kavaliou <Yury_Kavaliou@epam.com>

COPY ./files/sensu.repo /etc/yum.repos.d/sensu.repo
RUN yum install -y sensu \
	ruby \
	initscripts \
	supervisor \
	python-pip \
	&& gem install sensu-plugin \
	docker-api \
	sys-proctable \
	&& pip install sensu-plugin \
	docker-py
RUN cd / \
	&& curl -O https://kojipkgs.fedoraproject.org/packages/docker-io/1.4.1/8.fc21/x86_64/docker-io-1.4.1-8.fc21.x86_64.rpm  \
	&& rpm -Uhv docker-io-1.4.1-8.fc21.x86_64.rpm \
	&& rm docker-io-1.4.1-8.fc21.x86_64.rpm

COPY ./files/plugins/ /etc/sensu/plugins/
COPY ./files/pre_init.py /usr/local/sbin/pre_init.py
COPY ./files/sensu-init.sh /etc/sensu/sensu-init.sh

RUN chmod 700 /etc/sensu/sensu-init.sh \
    /usr/local/sbin/pre_init.py

# supervisord
COPY ./files/supervisord.conf /etc/supervisord.conf

ENTRYPOINT [ "python", "/usr/local/sbin/pre_init.py" ]