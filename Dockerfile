# jenkinsのダウンロードやプラグインのダウンロード
FROM gcr.io/distroless/java11-debian11:debug AS builder

ARG JENKINS_VERSION
ARG JENKINS_PLUGIN_MANAGER_VERSION

SHELL ["/busybox/sh", "-c"]

COPY ./requirements.txt /tmp/requirements.txt
RUN mkdir /usr/share/jenkins
RUN wget -P /usr/share/jenkins https://updates.jenkins-ci.org/download/war/${JENKINS_VERSION}/jenkins.war
RUN wget -P /tmp https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/${JENKINS_PLUGIN_MANAGER_VERSION}/jenkins-plugin-manager-${JENKINS_PLUGIN_MANAGER_VERSION}.jar
RUN mv /tmp/jenkins-plugin-manager-${JENKINS_PLUGIN_MANAGER_VERSION}.jar /tmp/jenkins-plugin-manager.jar

RUN java -jar /tmp/jenkins-plugin-manager.jar --war /usr/share/jenkins/jenkins.war -d /var/jenkins_home/plugins --plugin-file /tmp/requirements.txt

RUN unzip -d /tmp/jenkins/ /usr/share/jenkins/jenkins.war
RUN mkdir /tools
RUN find /tmp/jenkins/WEB-INF/lib -type f -name remoting*.jar | xargs -IARG cp ARG /tools/agent.jar


# エージェントに必要なagent.jarを所有する中間イメージ ホストOSに渡す際はdocker build--target tools -o tools .を実行
FROM scratch AS tools

COPY --from=builder /tools/agent.jar /agent.jar


# Jenkinsマスターイメージ
FROM gcr.io/distroless/java11-debian11 AS master
USER nonroot

ENV JAVA_TOOL_OPTIONS="-Duser.timezone=Asia/Tokyo -Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8 -Djenkins.install.runSetupWizard=false"
ENV JENKINS_HOME=/var/jenkins_home
ENV CASC_JENKINS_CONFIG=/var/jenkins_config

COPY --from=builder /usr/share/jenkins/jenkins.war /usr/share/jenkins/jenkins.war
COPY --from=builder --chown=nonroot:nonroot /var/jenkins_home /var/jenkins_home

VOLUME /var/jenkins_home
VOLUME /var/jenkins_config

EXPOSE 8080
EXPOSE 50000

CMD ["/usr/share/jenkins/jenkins.war"]


# Jenkinsエージェントイメージ
FROM gcr.io/distroless/java11-debian11 AS agent
USER nonroot

ENV JAVA_TOOL_OPTIONS="-Duser.timezone=Asia/Tokyo -Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"

COPY --from=tools --chown=nonroot:nonroot /agent.jar /usr/share/jenkins/agent.jar

CMD ["-jar", "/usr/share/jenkins/agent.jar", "-jnlpUrl", "http://master:8080/manage/computer/test%5Fnode/jenkins-agent.jnlp", "-workDir", "/usr/share/jenkins"]
