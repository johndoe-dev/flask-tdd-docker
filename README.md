# flask-tdd-docker

Updated skills by following the tutorial from [testdriven.io](https://testdriven.io/courses/tdd-flask/)
Resources:
* [Docs](https://mherman.org/presentations/dockercon-2018/#1)

## Create venv

Create a virtual environment `env` and activate it

```shell script
python3 -m venv env
```

```shell script
source env/bin/activate
```

## Flask

install `Flask` and  `Flask-RESTful`

```shell script
pip install flask flask-restful
```

The `project/__init__.py` module contains our flask app

The `manage.py` module contains the [`Flask Cli`](https://flask.palletsprojects.com/en/1.1.x/cli/) to manage the app from command line

### Config

The `project/config.py` module contains the environment [configuration](https://flask.palletsprojects.com/en/1.1.x/config/)

We add configuration to our app using
```python
app.config.from_object('project.config.DevelopmentConfig')
```

At this rate, to run the app, we need to:
* Set `FLASK_ENV` and `FLASK_APP` environment variable

```shell script
export FLASK_APP=project/__init__.py
export FLASK_ENV=development
```

* Run the app using the manage.py module

```shell script
python manage.py run
```

## Docker

### Dockerfile

We have a `Dockerfile` to the root of the project 

Take note of the following environment variables:
* `PYTHONDONTWRITEBYTECODE`: Prevents Python from writing pyc files to disc (equivalent to python -B [option](https://docs.python.org/3/using/cmdline.html#id1))
* `PYTHONUNBUFFERED`: Prevents Python from buffering stdout and stderr (equivalent to python -u [option](https://docs.python.org/3/using/cmdline.html#cmdoption-u))

> Depending on your environment, you may need to add RUN mkdir -p /usr/src/app just before you set the working directory:
> ```dockerfile
> # set working directory
> RUN mkdir -p /usr/src/app
> WORKDIR /usr/src/app
> ```

### Docker Compose

We have a `docker-compose.yml` to the root of the project

This config will create a service called users from the Dockerfile.

The volume is used to mount the code into the container. This is a must for a development environment in order to update the container whenever a change to the source code is made. Without this, you would have to re-build the image each time you make a change to the code.

Take note of the Docker compose file version used -- 3.7. Keep in mind that this version does not directly relate back to the version of Docker Compose installed; it simply specifies the file format that you want to use.

### Build & Run 

Build the image

```shell script
docker-compose build
```

Run in detach mode

```shell script
docker-compose up -d
```

Navigate to [http://localhost:5001/ping](http://localhost:5001/ping) 

In the `docker-compose.yml`, we add an environment variable to load the app config for the development environment:

```yaml
environment:
      - FLASK_APP=project/__init__.py
      - FLASK_ENV=development
      - APP_SETTINGS=project.config.DevelopmentConfig  # new
```

In the `project/__init__.py`, we pull the environment variables:

```python
import os
...

# set config
app_settings = os.getenv('APP_SETTINGS')
app.config.from_object(app_settings)

...
```

When we update the docker-compose.yml, we need to update the container:

```shell script
docker-compose up -d --build
```

To make sure the proper config was loaded, we can add a print statement just after `app.config.from_object(app_settings)`:

```python
import sys
print(app.config, file=sys.stderr)
```

To view docker logs:

```shell script
docker-compose logs
```

You should see:

<pre>
&lt;Config {'ENV': 'development', 'DEBUG': True, 'TESTING': False, 'PROPAGATE_EXCEPTIONS': None, 'PRESERVE_CONTEXT_ON_EXCEPTION': None, 'SECRET_KEY': None, 'PERMANENT_SESSION_LIFETIME': datetime.timedelta(days=31), 'USE_X_SENDFILE': False, 'SERVER_NAME': None, 'APPLICATION_ROOT': '/', 'SESSION_COOKIE_NAME': 'session', 'SESSION_COOKIE_DOMAIN': None, 'SESSION_COOKIE_PATH': None, 'SESSION_COOKIE_HTTPONLY': True, 'SESSION_COOKIE_SECURE': False, 'SESSION_COOKIE_SAMESITE': None, 'SESSION_REFRESH_EACH_REQUEST': True, 'MAX_CONTENT_LENGTH': None, 'SEND_FILE_MAX_AGE_DEFAULT': datetime.timedelta(seconds=43200), 'TRAP_BAD_REQUEST_ERRORS': None, 'TRAP_HTTP_EXCEPTIONS': False, 'EXPLAIN_TEMPLATE_LOADING': False, 'PREFERRED_URL_SCHEME': 'http', 'JSON_AS_ASCII': True, 'JSON_SORT_KEYS': True, 'JSONIFY_PRETTYPRINT_REGULAR': False, 'JSONIFY_MIMETYPE': 'application/json', 'TEMPLATES_AUTO_RELOAD': None, 'MAX_COOKIE_SIZE': 4093}>
</pre>

___Don't forget to remove the print statement.___

## POSTGRES

We added `Flask-SQLAlchemy` and `psycopg2-binary` to the `requirements.txt`

```text
Flask-SQLAlchemy==2.4.0
psycopg2-binary==2.8.3
``` 

We updated the `project/config.py` module to add `SQLALCHEMY_TRACK_MODIFICATIONS` and `SQLALCHEMY_DATABASE_URI`

* `SQLALCHEMY_TRACK_MODIFICATIONS` prevent to get notified before and after changes are committed to the database, when it sets to `False`
* `SQLALCHEMY_DATABASE_URI` is the database URI that should be used for the connection. 

```python
import os
...

class BaseConfig:
    """Base configuration"""
    ...
    SQLALCHEMY_TRACK_MODIFICATIONS = False

class DevelopmentConfig(BaseConfig):
    """Development configuration"""
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL')


class TestingConfig(BaseConfig):
    """Testing configuration"""
    ...
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_TEST_URL')


class ProductionConfig(BaseConfig):
    """Production configuration"""
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL')
```

We updated the `project/__init__.py` module to create a new instance of SQLAlchemy and define the database model:

```python
...

# instantiate the db
db = SQLAlchemy(app)

# model
class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    username = db.Column(db.String(128), nullable=False)
    email = db.Column(db.String(128), nullable=False)
    active = db.Column(db.Boolean(), default=True, nullable=False)

    def __init__(self, username, email):
        self.username = username
        self.email = email

...
```

We added a `db` directory to `project` and a `create.sql` file in it

```shell script
CREATE DATABASE users_dev;
CREATE DATABASE users_test;
CREATE DATABASE users_prod;
```

We added a `Dockerfile` in `project/db` to pull `postgres:11.4-alpine` and run create.sql on init

```dockerfile
# pull official base image
FROM postgres:11.4-alpine

# run create.sql on init
ADD create.sql /docker-entrypoint-initdb.d
```


We updated `docker-compose.yml` to add db services

```yaml
version: '3.7'

services:

    users:
      ...
      environment:
        ...
        - DATABASE_URL=postgresql://postgres:postgres@users-db:5432/users_dev
        - DATABASE_TEST_URL=postgresql://postgres:postgres@users-db:5432/users_test
      depends_on:
        - users-db
    
    
    users-db:  # new
      build:
        context: ./project/db
        dockerfile: Dockerfile
      expose:
        - 5432
      environment:
        - POSTGRES_USER=postgres
        - POSTGRES_PASSWORD=postgres
```

We added an `entrypoint.sh` file in the root:

```shell script
#!/bin/sh

echo "Waiting for postgres..."

while ! nc -z users-db 5432; do
  sleep 0.1
done

echo "PostgreSQL started"

python manage.py run -h 0.0.0.0
```

So, we referenced the Postgres container using the name of the service, users-db. The loop continues until something like Connection to users-db port 5432 \[tcp/postgresql] succeeded! is returned.

We updated `project/Dockerfile`

```dockerfile
# pull official base image
FROM python:3.7.4-alpine

# new
# install dependencies
RUN apk update && \
    apk add --virtual build-deps gcc python-dev musl-dev && \
    apk add postgresql-dev && \
    apk add netcat-openbsd

# set environment varibles
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# set working directory
WORKDIR /usr/src/app

# add and install requirements
COPY ./requirements.txt /usr/src/app/requirements.txt
RUN pip install -r requirements.txt

# new
# add entrypoint.sh
COPY ./entrypoint.sh /usr/src/app/entrypoint.sh
RUN chmod +x /usr/src/app/entrypoint.sh

# add app
COPY . /usr/src/app
```

We added an `entrypoint` to the `docker-compose.yml`

```yaml
version: '3.7'

services:

    users:
      build: ...
      entrypoint: ['/usr/src/app/entrypoint.sh']
    ...
```

We can run the server:

We use chmod +x to avoid `permisson denied`

> Depending on your environment, you may need to chmod 755 or 777 instead of +x.  
> If you still get a "permission denied", review the docker entrypoint running bash script gets "permission denied" Stack Overflow question.

```shell script
chmod +x entrypoint.sh
docker-compose up -d --build
```

Try to go [http://localhost:5001/ping](http://localhost:5001/ping)

We updated `manage.py` to register a new command, `recreate_db`, to the CLI so that we can run it from the command line, which we'll use shortly to apply the model to the database.

```python
from project import app, db

...

@cli.command('recreate_db')
def recreate_db():
    db.drop_all()
    db.create_all()
    db.session.commit()
```
