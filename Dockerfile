# Build using: docker build -f Dockerfile.gocd-agent -t gocd-agent .
FROM docker:1.10.2-dind

Add deploy/run.sh /run.sh
Add deploy/.sbt /root/.sbt/

Add bin/ /usr/local/bin/

# version is a mess as the zip doesn't include the build number..
RUN apk --no-cache add  bash unzip openjdk8 git curl openssh jq ca-certificates \
&& CONSUL_TEMPLATE_VERSION=0.14.0 \
&& wget https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip \
&& unzip consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip \
&& mv consul-template /usr/local/bin/consul-template \
&& rm consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip \
&& mkdir -p /consul-template /consul-template/config.d /consul-template/templates \
&& AGNT_VER=16.2.1 \
&& curl https://download.go.cd/binaries/${AGNT_VER}-3027/generic/go-agent-${AGNT_VER}-3027.zip  -o /tmp/go-agent.zip \
&& mkdir -p /opt \
&& cd /opt \
&& unzip /tmp/go-agent.zip \
&& chmod +x  /opt/go-agent-${AGNT_VER}/agent.sh \
&& ln -s /opt/go-agent-${AGNT_VER} /opt/go-agent \
&& rm -r /tmp/*
Add deploy/*.ctmpl  /consul-template/templates/
Add deploy/gocd-agent.json /consul-template/config.d/gocd-agent.json
ENV JAVA_HOME=/usr/lib/jvm/default-jvm GO_SERVER=go-server GO_SERVER_PORT=8153
WORKDIR /tmp
VOLUME ["/work","/cache"]
CMD ["/run.sh"]
