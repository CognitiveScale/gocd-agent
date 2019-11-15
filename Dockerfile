# Build using: docker build -f Dockerfile.gocd-agent -t gocd-agent .
FROM docker:1.11.2-dind

# version is a mess as the zip doesn't include the build number..
RUN apk --no-cache add python python3 py-pip bash unzip openjdk8-jre git curl openssh jq ca-certificates \
&& CONSUL_TEMPLATE_VERSION=0.14.0 \
&& wget https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip \
&& pip3 install -U setuptools wheel \
&& unzip consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip \
&& mv consul-template /usr/local/bin/consul-template \
&& rm consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip \
&& mkdir -p /consul-template /consul-template/config.d /consul-template/templates \
&& AGNT_VER=19.3.0-8959 \
&& HELM_VERSION="v2.14.3" \
&& FOLDER_NAME=go-agent-$(echo $AGNT_VER | cut -d'-' -f1) \
&& curl https://download.gocd.io/binaries/${AGNT_VER}/generic/go-agent-${AGNT_VER}.zip  -o /tmp/go-agent.zip \
&& mkdir -p /opt \
&& cd /opt \
&& unzip /tmp/go-agent.zip \
&& chmod +x  /opt/${FOLDER_NAME}/agent.sh \
&& pip install docker-compose==1.23.2 \
&& ln -s /opt/${FOLDER_NAME} /opt/go-agent \
&& rm -r /tmp/* \
&& mkdir -p /root/.config/git \
&& echo "cruise-output/" >> /root/.config/git/ignore \
&& YQ_VERSION=2.2.1 \
&& wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 \
&& mv yq_linux_amd64 yq \
&& chmod +x yq \
&& mv yq /usr/local/bin \
&& pip install awscli \
&& pip3 install ruamel.yaml \
&& wget https://raw.github.com/nvie/gitflow/develop/contrib/gitflow-installer.sh \
&& chmod +x gitflow-installer.sh \
&& ./gitflow-installer.sh \
&& wget https://github.com/git-lfs/git-lfs/releases/download/v2.9.0/git-lfs-linux-arm64-v2.9.0.tar.gz \
&& mkdir lfs \
&& tar -xvf git-lfs-linux-arm64-v2.9.0.tar.gz -C ./lfs \
&& install -v -m 0755 lfs/git-lfs /usr/local/bin/git-lfs \
&& git lfs install \
&& curl -LO https://storage.googleapis.com/kubernetes-helm/helm-${HELM_VERSION}-linux-amd64.tar.gz \
&& tar -zxvf helm-${HELM_VERSION}-linux-amd64.tar.gz linux-amd64/helm \
&& mv linux-amd64/helm /usr/local/bin/helm \
&& helm init --client-only

ADD deploy/run.sh /run.sh
ENV PATH="/opt/ci/bin:${PATH}"
# ADD bin/ /usr/local/bin/
# ADD etc/ /usr/local/etc/
ENV JAVA_HOME=/usr GO_SERVER=go-server GO_SERVER_PORT=8153
WORKDIR /tmp
VOLUME ["/work","/root"]
STOPSIGNAL HUP

CMD ["/run.sh"]
