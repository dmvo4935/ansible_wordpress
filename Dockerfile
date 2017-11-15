FROM centos

RUN yum -y update && yum -y install epel-release && yum -y install python-pip git
RUN pip install --upgrade pip
RUN pip install ansible

WORKDIR /opt

#RUN cd /opt
RUN git clone https://github.com/dmvo4935/ansible_wordpress.git 

#ADD inventory /opt/ansible_wordpress
#ADD ansible.sh /opt/ansible_wordpress


CMD [ "ansible_wordpress/ansible.sh" ]
