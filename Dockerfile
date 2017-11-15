FROM centos

RUN yum -y update && yum -y install epel-release && yum -y install python-pip git
RUN pip install --upgrade pip
RUN pip install ansible

RUN cd /opt
RUN git clone https://github.com/dmvo4935/ansible_wordpress.git 
WORKDIR /opt/ansible_wordpress

#COPY ./* /opt/ansible_wordpress
#ADD inventory /opt/ansible_wordpress
#ADD ansible.sh /opt/ansible_wordpress

CMD [/opt/ansible_wordpress/ansible.sh]
