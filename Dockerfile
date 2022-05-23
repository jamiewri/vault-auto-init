FROM vault:1.10.3
RUN echo -e "http://nl.alpinelinux.org/alpine/v3.5/main\nhttp://nl.alpinelinux.org/alpine/v3.5/community" > /etc/apk/repositories
RUN apk add --update --no-cache curl jq

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.19.7/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin/kubectl

RUN mkdir -p /tmp
COPY ./init.sh /tmp
