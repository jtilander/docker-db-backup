#!/usr/bin/python
#
# This scripts enumerates all the running database containers and then backs them up.
# Suitable to stick in a cron job.
#
import subprocess
import os
import sys
import logging
import json
from raven import Client
from raven.handlers.logging import SentryHandler
from raven.conf import setup_logging

HOSTNAME = os.environ.get('HOSTNAME', 'docker-container')

DATABASES = ['postgres', 'mysql']

ENVMAP = {
    'postgres': ('POSTGRES_DB', 'POSTGRES_USER', 'POSTGRES_PASSWORD', 'POSTGRES_ROOT_PASSWORD'),
    'mysql': ('MYSQL_DATABASE', 'MYSQL_USER', 'MYSQL_PASSWORD', 'MYSQL_ROOT_PASSWORD'),
}


def init_sentry():
    """ Initialize sentry client to report any errors """
    class FakeClient:
        def __init__(self):
            pass

        def captureException(self):
            import traceback
            print "--------------------------------------"
            print "Not running sentry in debugging mode."
            print ""
            traceback.print_exc()

        def user_context(self, d):
            for key in d.keys():
                print "%s: %s" % (key, d[key])

    debug = os.environ.get('DEBUG', '0')
    dsn = os.environ.get('SENTRY_DSN', '')
    if debug == '1' or len(dsn) == 0:
        return FakeClient()
    client = Client(dsn)
    handler = SentryHandler(client)
    handler.setLevel(logging.WARN)
    setup_logging(handler)
    return client


def containers_ps():
    """ Simply lists all the running container ids in the system """
    stream = os.popen('docker ps -q').read()
    lines = stream.splitlines(False)
    return lines


def container_image(id):
    """ Given a container id, return the image name """
    s = os.popen('docker inspect %s' % id).read()
    d = json.loads(s)
    i = d[0]['Config']['Image'].split(':')
    return i[0]


def container_name(id):
    """ Given a container id, return the name of the container """
    s = os.popen('docker inspect %s' % id).read()
    d = json.loads(s)
    i = d[0]['Name']
    return i[1:]


def container_env(id):
    s = os.popen('docker inspect %s' % id).read()
    d = json.loads(s)
    e = d[0]['Config']['Env']

    env = dict()
    for i in e:
        k, v = i.split('=', 1)
        env[k] = v
    return env


def backup_all(basedir, sentry):
    for id in containers_ps():
        image = container_image(id)
        name = container_name(id)

        logging.debug("Considering %s %s" % (name, image))
        if image not in DATABASES:
            continue
        logging.info("Found database %s container %s" % (image, name))

        env = container_env(id)

        kdatabase, kuser, kpassword, krootpassword = ENVMAP[image]

        database = env.get(kdatabase, 'none')
        user = env.get(kuser, 'root')
        password = env.get(kpassword, env.get(krootpassword, ''))
        prefix = 'backup_%s' % name

        command = 'docker run --rm ' +      \
            '-v %(basedir)s:/data ' +       \
            '-v /var/run/docker.sock:/var/run/docker.sock ' + \
            '-e DBNAME=%(database)s ' +     \
            '-e USERNAME=%(user)s ' +       \
            '-e PASSWORD=%(password)s ' +   \
            '-e DBTYPE=%(image)s ' +        \
            '-e CONTAINER=%(id)s ' +        \
            '-e PREFIX=%(prefix)s ' +       \
            '-e DEBUG=0 ' +                 \
            'jtilander/backup-db backup'

        command = command % locals()

        logging.debug(command)
        try:
            output = subprocess.check_output(command, stderr=subprocess.STDOUT, shell=True)
            for line in output.splitlines():
                logging.info('%s' % line.rstrip())
            logging.info('Backup of %s successful' % id)
        except subprocess.CalledProcessError as e:
            # lines = [x.strip() for x in e.output.splitlines()]
            # logging.error("%s" % command)
            # for line in lines:
            #     logging.error(line, )

            sentry.user_context({
                'command': command,
                'hostname': HOSTNAME,
                'output': e.output
            })
            sentry.captureException()


def main(basedir):
    if '1' == os.environ.get('DEBUG', '0'):
        logging.basicConfig(level=logging.DEBUG, format='%(asctime)-15s %(levelname)-8s %(message)s')
    else:
        logging.basicConfig(level=logging.INFO, format='%(asctime)-15s %(levelname)-8s %(message)s')

    sentry = init_sentry()
    try:
        backup_all(basedir, sentry)
    except Exception as e:
        sentry.captureException()
        print e
        sys.exit(1)

    sys.exit(0)


if __name__ == '__main__':
    main(sys.argv[1])