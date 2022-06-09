# ems-db-system-api

ARG         BASE_IMAGE=
FROM        $BASE_IMAGE

ARG         JAR_NAME=

COPY        ${JAR_NAME} /opt/mule/apps/

CMD         ["/opt/mule/bin/start.sh"]