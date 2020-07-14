FROM drecom/centos-ruby:2.6.5-slim

RUN yum -y install openssl-devel openssl
RUN yum -y groupinstall "Development Tools"

WORKDIR /
COPY /transfer_app/ /app/

COPY curl-7.71.1.tar.gz /
RUN tar -xvf curl-7.71.1.tar.gz
RUN /bin/bash -c "curl-7.71.1/./configure --without-nss --with-openssl"
WORKDIR curl-7.71.1
RUN make && make install

RUN yum -y install libcurl-devel

WORKDIR /app
RUN bundle install