FROM jtilander/alpine
MAINTAINER Jim Tilander

RUN apk add --no-cache \
		bash \
		dcron \
		docker

ENV DEBUG=0 \
	HISTORY=5 \
	DBNAME=database_name \
	USERNAME=root \
	PASSWORD=password \
	DBTYPE=mysql \
	PREFIX=backup \
	CONTAINER=

ENV	CRONSCHEDULE='0 * * * *'

RUN mkdir -p /app
COPY backup-*.sh restore-*.sh /app/
COPY mail.sh /app/

RUN mkdir -p /data
WORKDIR /data

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["backup"]

ENV TINI_VERSION v0.14.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static /sbin/tini
RUN chmod +x /sbin/tini
