IMAGENAME?=jtilander/backup-db
TAG?=latest
DEBUG?=1
DBNAME?=test
PASSWORD?=password
HISTORY?=5
USERNAME?=root
CONTAINER?=
DBTYPE?=mysql

.PHONY: image clean run debug

ENVIRONMENT=-e DBTYPE=$(DBTYPE) \
			-e CONTAINER=$(CONTAINER) \
			-e DEBUG=$(DEBUG) \
			-e DBNAME=$(DBNAME) \
			-e PASSWORD=$(PASSWORD) \
			-e HISTORY=$(HISTORY) \
			-e USERNAME=$(USERNAME) \
			-e SENTRY_DSN=$(SENTRY_DSN) \
			-e HOSTNAME=$(HOSTNAME)

VOLUMES=-v $(PWD)/tmp/backup:/data \
		-v /var/run/docker.sock:/var/run/docker.sock

image:
	@docker build -t $(IMAGENAME):$(TAG) .
	@docker images $(IMAGENAME):$(TAG)

clean:
	@docker run --rm -v $(PWD)/tmp:/data alpine:3.5 /bin/sh -c 'rm -rf /data/*'
	@docker rmi `docker images -q $(IMAGENAME):$(TAG)`

backup:
	@docker run --rm $(ENVIRONMENT) $(VOLUMES) $(IMAGENAME):$(TAG) backup

restore:
	@docker run --rm $(ENVIRONMENT) $(VOLUMES) $(IMAGENAME):$(TAG) restore

cron:
	@docker run --rm $(ENVIRONMENT) $(VOLUMES) $(IMAGENAME):$(TAG) cron

debug:
	@docker run --rm -it $(ENVIRONMENT) $(IMAGENAME):$(TAG) bash

push:
	@docker push $(IMAGENAME):$(TAG)

login:
	@docker login -u jtilander

test:
	@docker-compose down && docker-compose up -d && docker-compose logs -f

iterate:
	docker run --rm $(ENVIRONMENT) \
	$(VOLUMES) \
	-v $(PWD)/backup-all.py:/app/backup-all.py \
	-v $(PWD)/backup-all.sh:/app/backup-all.sh \
	-v $(PWD)/backup-mysql.sh:/app/backup-mysql.sh \
	-v $(PWD)/backup-psql.sh:/app/backup-psql.sh \
	-e TAG=$(TAG) \
	$(IMAGENAME):$(TAG) backup $(PWD)/tmp/all

