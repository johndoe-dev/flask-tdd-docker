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

## TEST

We added a `tests` python package into `project` and added the following files:
* `__init__.py`
* `conftest.py`
* `pytest.ini`
* `test_config.py`
* `test_ping.py`


In `conftest.py`, w define a `test_app` and `test_database` (for initializing a test database) [`fixture`](https://docs.pytest.org/en/latest/fixture.html) in conftest.py:

```python
import pytest

from project import app, db


@pytest.fixture(scope='module')
def test_app():
    app.config.from_object('project.config.TestingConfig')
    with app.app_context():
        yield app  # testing happens here


@pytest.fixture(scope='module')
def test_database():
    db.create_all()
    yield db  # testing happens here
    db.session.remove()
    db.drop_all()
```

equivalent of `test_database()` with [`unittest`](https://docs.python.org/fr/3/library/unittest.html) is:

```python
def setUp(self):
    db.create_all()

def tearDown(self):
    db.session.remove()
    db.drop_all()
```

All code before the yield statement serves as setup code while everything after serves as the teardown.

We added `pytest==5.0.1` to the `requirements.txt`

We need to re-build the Docker images since requirements are installed at build time rather than run time:

```shell script
docker-compose up -d --build
```

And we can run the tests once the containers are up:

```shell script
docker-compose exec users pytest "project/tests"
```

You should see:

<pre>
======================================== test session starts ========================================
platform linux -- Python 3.7.4, pytest-5.0.1, py-1.8.0, pluggy-0.12.0
rootdir: /usr/src/app/project/tests, inifile: pytest.ini
collected 0 items

=================================== no tests ran in 0.06 seconds ====================================
</pre>

Now, we add some tests in `test_config.py`

```python
import os


def test_development_config(test_app):
    test_app.config.from_object('project.config.DevelopmentConfig')
    assert test_app.config['SECRET_KEY'] == 'my_precious'
    assert not test_app.config['TESTING']
    assert test_app.config['SQLALCHEMY_DATABASE_URI'] == os.environ.get('DATABASE_URL')


def test_testing_config(test_app):
    test_app.config.from_object('project.config.TestingConfig')
    assert test_app.config['SECRET_KEY'] == 'my_precious'
    assert test_app.config['TESTING']
    assert not test_app.config['PRESERVE_CONTEXT_ON_EXCEPTION']
    assert test_app.config['SQLALCHEMY_DATABASE_URI'] == os.environ.get('DATABASE_TEST_URL')


def test_production_config(test_app):
    test_app.config.from_object('project.config.ProductionConfig')
    assert test_app.config['SECRET_KEY'] == 'my_precious'
    assert not test_app.config['TESTING']
    assert test_app.config['SQLALCHEMY_DATABASE_URI'] == os.environ.get('DATABASE_URL')
```

While unittest requires test classes, Pytest just requires functions to get up and running. In other words, Pytest tests are just functions that either start or end with test.

To use the fixture, we passed it in as an argument.

You should see the following error:

<pre>
>       assert test_app.config['SECRET_KEY'] == 'my_precious'
E       AssertionError: assert None == 'my_precious'
</pre>

We need to update the `BaseConfig` class in `project/config.py` and add `SECRET_KEY = 'my_precious'

When we re-test:

<pre>
========================================================================================================== test session starts ===========================================================================================================
platform linux -- Python 3.7.4, pytest-5.0.1, py-1.8.0, pluggy-0.13.0
rootdir: /usr/src/app
collected 3 items                                                                                                                                                                                                                        

project/tests/test_config.py ...                                                                                                                                                                                                   [100%]

======================================================================================================== 3 passed in 0.07 seconds ========================================================================================================
</pre>

We add now a functional test in `test_ping.py`

```python
import json


def test_ping(test_app):
    client = test_app.test_client()
    resp = client.get('/ping')
    data = json.loads(resp.data.decode())
    assert resp.status_code == 200
    assert 'pong' in data['message']
    assert 'success' in data['status']
```

Result of test:

<pre>
========================================================================================================== test session starts ===========================================================================================================
platform linux -- Python 3.7.4, pytest-5.0.1, py-1.8.0, pluggy-0.13.0
rootdir: /usr/src/app/project/tests, inifile: pytest.ini
collected 4 items                                                                                                                                                                                                                        

project/tests/test_config.py ...                                                                                                                                                                                                   [ 75%]
project/tests/test_ping.py .                                                                                                                                                                                                       [100%]

======================================================================================================== 4 passed in 0.10 seconds ========================================================================================================
</pre>

> Did you notice that the tests in test_config.py are unit tests while the tests in test_ping.py are functional? You may want to differentiate between the two by splitting them out into separate folders, like so:
> <pre>
> └── tests
>   ├── __init__.py
>   ├── conftest.py
>   ├── functional
>   │   └── test_ping.py
>   ├── pytest.ini
>   └── unit
>       └── test_config.py
> </pre>
> With this structure you have the flexibility to run a single type of test at a time. You can also check code coverage for a single type of test.