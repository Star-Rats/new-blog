FROM java:8
MAINTAINER jiangmingyang@pinsmedical.com
ENV DEPLOY_HOME=/home/deploy
WORKDIR ${DEPLOY_HOME}
VOLUME ${DEPLOY_HOME}/log
COPY target/*.jar ${DEPLOY_HOME}/blog.jar
RUN ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
&& echo Asis/Shanghai > /etc/timezone
EXPOSE ${SERVER_PORT}
ENTRYPOINT ["java","-Xms128m","-Xmx256m","-jar","blog.jar"]   
CMD ["--server.port=${SERVER_PORT}"]