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
from pprint import pprint

HOSTNAME = os.environ.get('HOSTNAME', 'docker-container')
TAG = os.environ.get('TAG', 'latest')

DATABASES = {
    'postgres': ['postgres'],
    'mysql': ['mysql']
}


ENVMAP = {
    'postgres': ('POSTGRES_DB', 'POSTGRES_USER', 'POSTGRES_PASSWORD', 'POSTGRES_PASSWORD', 'postgres'),
    'mysql': ('MYSQL_DATABASE', 'MYSQL_USER', 'MYSQL_PASSWORD', 'MYSQL_ROOT_PASSWORD', 'root'),
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
    global DATABASES

    DATABASES['postgres'] += os.environ.get('EXTRA_PSQL', '').split()
    DATABASES['mysql'] += os.environ.get('EXTRA_MYSQL', '').split()

    # pprint(DATABASES)

    failures = 0
    for id in containers_ps():
        image = container_image(id)
        name = container_name(id)

        logging.debug("Considering %s %s" % (name, image))
        database_type = None
        if image in DATABASES['postgres']:
            logging.debug('Image %s is in the postgres list %s' % (image, DATABASES['postgres']))
            database_type = 'postgres'
        if image in DATABASES['mysql']:
            logging.debug('Image %s is in the mysql list %s' % (image, DATABASES['mysql']))
            database_type = 'mysql'
        if database_type is None:
            continue
        logging.info("Found database %s container %s" % (database_type, name))

        env = container_env(id)

        kdatabase, kuser, kpassword, krootpassword, defaultuser = ENVMAP[database_type]

        database = env.get(kdatabase, 'none')
        user = env.get(kuser, defaultuser)
        if defaultuser == user:
            password = env.get(krootpassword, '')
        else:
            password = env.get(kpassword, '')

            # If there is also a root password set, run as the root user instead.
            if kpassword != krootpassword and env.get(krootpassword, '') != '':
                password = env.get(krootpassword, '')
                user = defaultuser

        prefix = 'backup_%s' % name

        history = os.environ.get('HISTORY', '3')

        command = 'docker run --rm ' +      \
            '-v %(basedir)s:/data ' +       \
            '-v /var/run/docker.sock:/var/run/docker.sock ' + \
            '-e DBNAME=%(database)s ' +     \
            '-e USERNAME=%(user)s ' +       \
            '-e PASSWORD=%(password)s ' +   \
            '-e DBTYPE=%(database_type)s ' +        \
            '-e CONTAINER=%(id)s ' +        \
            '-e PREFIX=%(prefix)s ' +       \
            '-e DEBUG=0 ' +                 \
            '-e HISTORY=%(history)s ' +     \
            'jtilander/backup-db:%s backup' % TAG

        command = command % locals()

        logging.debug(command)
        try:
            output = subprocess.check_output(command, stderr=subprocess.STDOUT, shell=True)
            for line in output.splitlines():
                logging.info('%s' % line.rstrip())
            logging.info('Backup of %s successful' % id)
        except subprocess.CalledProcessError as e:
            sentry.user_context({
                'command': command,
                'hostname': HOSTNAME,
                'output': e.output
            })
            sentry.captureException()

            failures += 1

    return failures


def main(basedir):
    if '1' == os.environ.get('DEBUG', '0'):
        logging.basicConfig(level=logging.DEBUG, format='%(levelname)-8s %(message)s')
    else:
        logging.basicConfig(level=logging.INFO, format='%(levelname)-8s %(message)s')

    sentry = init_sentry()
    try:
        failures = backup_all(basedir, sentry)
    except Exception as e:
        sentry.captureException()
        print e
        sys.exit(1)

    sys.exit(failures)


if __name__ == '__main__':
    main(sys.argv[1])
