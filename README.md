# flask-tdd-docker

[![pipeline status](https://gitlab.com/johndoe-dev-tdd/flask-tdd-docker/badges/master/pipeline.svg)](https://gitlab.com/johndoe-dev-tdd/flask-tdd-docker/commits/master)

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


## Flask Blueprint

Now we need to refactor the app and adding in `Blueprints`

We need to create an `api` package into `project` and add the modules `ping.py`, `models.py` and `users.py`

In `api/ping.py`

```python
from flask import Blueprint
from flask_restful import Resource, Api


ping_blueprint = Blueprint('ping', __name__)
api = Api(ping_blueprint)


class Ping(Resource):
    def get(self):
        return {
            'status': 'success',
            'message': 'pong!'
        }


api.add_resource(Ping, '/ping')
```

In `api/models.py`

```python
from sqlalchemy.sql import func

from project import db


class User(db.Model):

    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    username = db.Column(db.String(128), nullable=False)
    email = db.Column(db.String(128), nullable=False)
    active = db.Column(db.Boolean(), default=True, nullable=False)
    created_date = db.Column(db.DateTime, default=func.now(), nullable=False)

    def __init__(self, username, email):
        self.username = username
        self.email = email

```

Now we will an [`Application`](https://flask.palletsprojects.com/en/1.1.x/patterns/appfactories/) factory pattern in `project/__init__.py` and remove route and models

```python
import os
from flask import Flask
from flask_sqlalchemy import SQLAlchemy

# instantiate the db
db = SQLAlchemy()


def create_app(script_info=None):

    # instantiate the app
    app = Flask(__name__)

    # set config
    app_settings = os.getenv('APP_SETTINGS')
    app.config.from_object(app_settings)

    # set up extensions
    db.init_app(app)

    # register blueprints
    from project.api.ping import ping_blueprint
    app.register_blueprint(ping_blueprint)

    # shell context for flask cli
    @app.shell_context_processor
    def ctx():
        return {'app': app, 'db': db}

    return app
```

Take note of the [`shell_context_processor`](https://flask.palletsprojects.com/en/1.1.x/api/#flask.Flask.shell_context_processor). It's used to register the `app` and `db` to the shell. Now we can work with the application context and the database without having to import them directly into the shell, which you'll see shortly.

We need to update `manage.py`

```python
...
from project import create_app, db
from project.api.models import User

app = create_app()
cli = FlaskGroup(create_app=create_app)

...
```

Now, we can work with the app and db context directly:

```shell script
docker-compose up -d
docker-compose exec users flask shell
```

Result:
<pre>
Python 3.7.4 (default, Aug 21 2019, 00:19:59) 
[GCC 8.3.0] on linux
App: project [development]
Instance: /usr/src/app/instance
>>> app
&lt;Flask 'project'>
>>> db
&lt;SQLAlchemy engine=postgresql://postgres:***@users-db:5432/users_dev>
</pre>

We need to update `project/tests/conftest.py` to import `create_app` whis is an instance of the app

```python
...
from project import create_app, db

@pytest.fixture(scope='module')
def test_app():
    app = create_app()
    ...
...
```

Finally, we just need to remove the `FLASK_APP` environment variable from `docker-compose.yml`

```yaml
environment:
  - FLASK_ENV=development
  - APP_SETTINGS=project.config.DevelopmentConfig
  - DATABASE_URL=postgresql://postgres:postgres@users-db:5432/users_dev
  - DATABASE_TEST_URL=postgresql://postgres:postgres@users-db:5432/users_test
```

We can run the test

```shell script
docker-compose up -d
docker-compose exec users pytest "project/tests"
```

We can now apply the model to the dev database

```shell script
docker-compose exec users python manage.py recreate_db
```

Now check in psql

```shell script
docker-compose exec users-db psql -U postgres
```

Result

<pre>
psql (11.4)
Type "help" for help.

postgres=# \c users_dev
You are now connected to database "users_dev" as user "postgres".
users_dev=# \dt
         List of relations
 Schema | Name  | Type  |  Owner   
--------+-------+-------+----------
 public | users | table | postgres
(1 row)

users_dev=# \q
</pre>

## RESTful Routes

Now, we add 3 new routes:

Endpoint | HTTP Method | CRUD Method | Result
--- | --- | --- | ---
/users | GET | READ | get all users
/users/:id | GET | READ | get a single user
/users | POST | CREATE | add a user

For each, we'll:

1. write a test
2. run the test, to ensure it fails (`red`)
3. write just enough code to get the test to pass (`green`)
4. refactor (if necessary)

Let's start with the POST route.

### POST

We need to add a module `test_users.py` to `project/tests`

```python
import json


def test_add_user(test_app, test_database):
    client = test_app.test_client()
    resp = client.post(
        '/users',
        data=json.dumps({
            'username': 'michael',
            'email': 'michael@testdriven.io'
        }),
        content_type='application/json',
    )
    data = json.loads(resp.data.decode())
    assert resp.status_code == 201
    assert 'michael@testdriven.io was added!' in data['message']
    assert 'success' in data['status']
```

Now run the test to ensure it fails

```shell script
docker-compose exec users pytest "project/tests"
```

Add the route handler to `project/api/users.py`

```python
from flask import Blueprint, request
from flask_restful import Resource, Api

from project import db
from project.api.models import User


users_blueprint = Blueprint('users', __name__)
api = Api(users_blueprint)


class UsersList(Resource):
    def post(self):
        post_data = request.get_json()
        username = post_data.get('username')
        email = post_data.get('email')
        db.session.add(User(username=username, email=email))
        db.session.commit()
        response_object = {
            'status': 'success',
            'message': f'{email} was added!'
        }
        return response_object, 201


api.add_resource(UsersList, '/users')

```

Register the blueprint in `project/__init__.py`

```python
from project.api.users import users_blueprint
app.register_blueprint(users_blueprint)
```

Run the test again

> If we have some warning, you can pass `-p no:warnings` on the command-line in to disable them.  
> Or add the following lines in the `project/tests/pytest.ini`
> ```buildoutcfg
> [pytest]
> addopts = -p no:warnings
> ```
> See [here](https://docs.pytest.org/en/latest/warnings.html#disabling-warning-capture-entirely) for more information

```shell script
docker-compose exec users pytest "project/tests" {-p no:warnings}
```

What about errors and exceptions? Like:

1. A payload is not sent
2. The payload is invalid -- i.e., the JSON object is empty or it contains the wrong keys
3. The user already exists in the database

We need to add some tests in `project/tests/test_users.py`

```python
def test_add_user_invalid_json(test_app, test_database):
    client = test_app.test_client()
    resp = client.post(
        '/users',
        data=json.dumps({}),
        content_type='application/json',
    )
    data = json.loads(resp.data.decode())
    assert resp.status_code == 400
    assert 'Invalid payload.' in data['message']
    assert 'fail' in data['status']


def test_add_user_invalid_json_keys(test_app, ):
    client = test_app.test_client()
    resp = client.post(
        '/users',
        data=json.dumps({"email": "john@testdriven.io"}),
        content_type='application/json',
    )
    data = json.loads(resp.data.decode())
    assert resp.status_code == 400
    assert 'Invalid payload.' in data['message']
    assert 'fail' in data['status']


def test_add_user_duplicate_email(test_app, test_database):
    client = test_app.test_client()
    client.post(
        '/users',
        data=json.dumps({
            'username': 'michael',
            'email': 'michael@testdriven.io'
        }),
        content_type='application/json',
    )
    resp = client.post(
        '/users',
        data=json.dumps({
            'username': 'michael',
            'email': 'michael@testdriven.io'
        }),
        content_type='application/json',
    )
    data = json.loads(resp.data.decode())
    assert resp.status_code == 400
    assert 'Sorry. That email already exists.' in data['message']
    assert 'fail' in data['status']
```

Ensure the tests fails by running:

```shell script
docker-compose exec users pytest "project/tests"
```

Update the route handler

```python
from sqlalchemy import exc

...

class UsersList(Resource):
    def post(self):
        post_data = request.get_json()
        response_object = {
            'status': 'fail',
            'message': 'Invalid payload.'
        }
        if not post_data:
            return response_object, 400
        username = post_data.get('username')
        email = post_data.get('email')
        try:
            user = User.query.filter_by(email=email).first()
            if not user:
                db.session.add(User(username=username, email=email))
                db.session.commit()
                response_object['status'] = 'success'
                response_object['message'] = f'{email} was added!'
                return response_object, 201
            else:
                response_object['message'] = 'Sorry. That email already exists.'
                return response_object, 400
        except exc.IntegrityError:
            db.session.rollback()
            return response_object, 400
```

Ensure the tests pass

### GET single user

We start by writing the test in `project/tests/test_users.py`

```python
...

from project import db
from project.api.models import User

...

def test_single_user(test_app, test_database):
    user = User(username='jeffrey', email='jeffrey@testdriven.io')
    db.session.add(user)
    db.session.commit()
    client = test_app.test_client()
    resp = client.get(f'/users/{user.id}')
    data = json.loads(resp.data.decode())
    assert resp.status_code == 200
    assert 'jeffrey' in data['data']['username']
    assert 'jeffrey@testdriven.io' in data['data']['email']
    assert 'success' in data['status']
```

Ensure the test breaks and write the route

```python
class Users(Resource):
    def get(self, user_id):
        user = User.query.filter_by(id=user_id).first()
        response_object = {
            'status': 'success',
            'data': {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'active': user.active
            }
        }
        return response_object, 200

...
api.add_resource(Users, '/users/<user_id>')
```

The tests should pass. Now, what about error handling?

1. An id is not provided
2. The id does not exist

Tests:

```python
def test_single_user_no_id(test_app, test_database):
    client = test_app.test_client()
    resp = client.get('/users/blah')
    data = json.loads(resp.data.decode())
    assert resp.status_code == 404
    assert 'User does not exist' in data['message']
    assert 'fail' in data['status']


def test_single_user_incorrect_id(test_app, test_database):
    client = test_app.test_client()
    resp = client.get('/users/999')
    data = json.loads(resp.data.decode())
    assert resp.status_code == 404
    assert 'User does not exist' in data['message']
    assert 'fail' in data['status']
```

Update the route

```python
class Users(Resource):
    def get(self, user_id):
        response_object = {
            'status': 'fail',
            'message': 'User does not exist'
        }
        try:
            user = User.query.filter_by(id=int(user_id)).first()
            if not user:
                return response_object, 404
            else:
                response_object = {
                    'status': 'success',
                    'data': {
                        'id': user.id,
                        'username': user.username,
                        'email': user.email,
                        'active': user.active
                    }
                }
                return response_object, 200
        except ValueError:
            return response_object, 404
```

### GET all users

Again, let's start with a test.

Since we'll have to add a few users first, let's add a quick helper function to a new utility file called `project/tests/utils.py`

```python
from project import db
from project.api.models import User


def add_user(username, email):
    user = User(username=username, email=email)
    db.session.add(user)
    db.session.commit()
    return user
```

Now, refactor the `test_single_user` test, like so:

```python
from project.tests.utils import add_user

...

def test_single_user(test_app, test_database):
    user = add_user('jeffrey', 'jeffrey@testdriven.io')
    client = test_app.test_client()
    resp = client.get(f'/users/{user.id}')
    data = json.loads(resp.data.decode())
    assert resp.status_code == 200
    assert 'jeffrey' in data['data']['username']
    assert 'jeffrey@testdriven.io' in data['data']['email']
    assert 'success' in data['status']
```

Remove these imports

```python
from project import db
from project.api.models import User
```

Make sure the test still pass

```shell script
docker-compose exec users pytest "project/tests"
```

Now let's add the new test

```python
def test_all_users(test_app, test_database):
    add_user('michael', 'michael@mherman.org')
    add_user('fletcher', 'fletcher@notreal.com')
    client = test_app.test_client()
    resp = client.get('/users')
    data = json.loads(resp.data.decode())
    assert resp.status_code == 200
    assert len(data['data']['users']) == 2
    assert 'michael' in data['data']['users'][0]['username']
    assert 'michael@mherman.org' in data['data']['users'][0]['email']
    assert 'fletcher' in data['data']['users'][1]['username']
    assert 'fletcher@notreal.com' in data['data']['users'][1]['email']
    assert 'success' in data['status']
```

Make sure it fails. Then add the view to the `UsersList` resource:

```python
def get(self):
    response_object = {
        'status': 'success',
        'data': {
            'users': [user.to_json() for user in User.query.all()]
        }
    }
    return response_object, 200
```

Add the `to_json` method to the model:

```python
def to_json(self):
    return {
        'id': self.id,
        'username': self.username,
        'email': self.email,
        'active': self.active
    }
```

Run the test

```shell script
docker-compose exec users pytest "project/tests"
```

Result

<pre>
>       assert len(data['data']['users']) == 2
E       AssertionError: assert 4 == 2
E        +  where 4 = len([{'active': True, 'email': 'michael@testdriven.io', 'id': 1, 'username': 'michael'}, {'active': True, 'email': 'jeffre...', 'id': 4, 'username': 'michael'}, {'active': True, 'email': 'fletcher@notreal.com', 'id': 5, 'username': 'fletcher'}])
</pre>

The test failed

Why are there four users? Essentially, we added a single user each in the `test_add_user` and `test_single_user` tests. Two more get added in the `test_all_users`. We could fix this by changing the tests to:

```python
def test_all_users(test_app, test_database):
    add_user('michael', 'michael@mherman.org')
    add_user('fletcher', 'fletcher@notreal.com')
    client = test_app.test_client()
    resp = client.get('/users')
    data = json.loads(resp.data.decode())
    assert resp.status_code == 200
    assert len(data['data']['users']) == 4
    assert 'michael' in data['data']['users'][2]['username']
    assert 'michael@mherman.org' in data['data']['users'][2]['email']
    assert 'fletcher' in data['data']['users'][3]['username']
    assert 'fletcher@notreal.com' in data['data']['users'][3]['email']
    assert 'success' in data['status']
```

However, what would happen if another developer changed the number of users added in either `test_add_user` or `test_single_user`?

When writing tests, it's a good idea to run each test in isolation to ensure that each can be run mostly on their own. This makes it easier to run tests in parallel and it helps reduce flaky tests. When there's shared testing code, it's easy for other developers to change that code and have other tests break or produce false positives. Don't worry so much about keeping your tests DRY, in other words.

Let's add another helper to wipe the database in `project/tests/utils.py`:

```python
def recreate_db():
    db.session.remove()
    db.drop_all()
    db.create_all()
```

Add `recreate_db` in `test_all_users`, don't forget to import it:

```python
...
from project.tests.utils import add_user, recreate_db

...
def test_all_users(test_app, test_database):
    recreate_db()
    ...
```

The test should pass now

Let's test the route in the browser: [http://localhost:5000/users](http://localhost:5000/users)

Result

<pre>
{
    "status": "success",
    "data": {
        "users": []
    }
}
</pre>

Add a seed command to the `manage.py` file to populate the database with some initial data:

```python
@cli.command('seed_db')
def seed_db():
    """Seeds the database."""
    db.session.add(User(username='michael', email="hermanmu@gmail.com"))
    db.session.add(User(username='michaelherman', email="michael@mherman.org"))
    db.session.commit()
```

Try it:

```shell script 
docker-compose exec users python manage.py seed_db
```

Now, you should have some data in the browser: [http://localhost:5000/users](http://localhost:5000/users)


## Deployment

We will deployed the app on Heroku

### Gunicorn

We need to add gunicorn to the `requirements.txt`

Create a `Dockerfile.prod` to the root of the project

```dockerfile
# pull official base image
FROM python:3.7.4-alpine

# install dependencies
RUN apk update && \
    apk add --virtual build-deps gcc python-dev musl-dev && \
    apk add postgresql-dev && \
    apk add netcat-openbsd

# set working directory
WORKDIR /usr/src/app

# set environment varibles
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV FLASK_ENV production
ENV APP_SETTINGS project.config.ProductionConfig

# add and install requirements
COPY ./requirements.txt /usr/src/app/requirements.txt
RUN pip install -r requirements.txt

# add app
COPY . /usr/src/app

# add and run as non-root user
RUN adduser -D myuser
USER myuser

# run gunicorn
CMD gunicorn --bind 0.0.0.0:$PORT manage:app
```

We add 2 new environment variables:

```dockerfile
ENV FLASK_ENV production
ENV APP_SETTINGS project.config.ProductionConfig
```

We also created and switched to a non-root user, which is [`recommended by Heroku`](https://devcenter.heroku.com/articles/container-registry-and-runtime#run-the-image-as-a-non-root-user).

Finally, take note of the `$PORT` environment variable in the Gunicorn command. Essentially, our web app must be listening on a particular port specified by the `$PORT` environment variable, which is [`supplied by Heroku`](https://devcenter.heroku.com/articles/dynos#web-dynos).

### Heroku

We must [`Sign in`](https://id.heroku.com/login) on Heroku (or [`Sign Up`](https://signup.heroku.com)).
We need to install [`Heroku CLI`](https://devcenter.heroku.com/articles/heroku-cli)

We need to create a new app:

```shell script
heroku create [APP]
```

Result

<pre>
Creating app... !
 ▸    Invalid credentials provided.
heroku: Press any key to open up the browser to login or q to exit: 
&lt;Login to Hero Cli>
Creating app... done, ⬢ vast-refuge-42324
https://vast-refuge-42324.herokuapp.com/ | https://git.heroku.com/vast-refuge-42324.git

</pre>

Log in to the [`Heroku Container Registry`](https://devcenter.heroku.com/articles/container-registry-and-runtime):

```shell script
heroku container:login
```

Result

<pre>
Login Succeeded
</pre>

Provision a new Postgres database with the [`hobby-dev`](https://devcenter.heroku.com/articles/heroku-postgres-plans#hobby-tier) plan:

```shell script
heroku addons:create heroku-postgresql:hobby-dev
```

Result

<pre>
Creating heroku-postgresql:hobby-dev on ⬢ vast-refuge-42324... free
Database has been created and is available
 ! This database is empty. If upgrading, you can transfer
 ! data from another database with pg:copy
Created postgresql-spherical-67833 as DATABASE_URL
Use heroku addons:docs heroku-postgresql to view documentation
</pre>

To view the documentation

```shell script
heroku addons:docs heroku-postgresql
```

Build the production image and tag it with the following format:

```shell script
registry.heroku.com/<app>/<process-type>
```

Make sure to replace `<app>` with the name of the Heroku app that you just created and `<process-type>` with `web` since this will be a [`web dyno`](https://www.heroku.com/dynos).

Here the command:

```shell script
docker build -f Dockerfile.prod -t registry.heroku.com/vast-refuge-42324/web .
```

To test locally, we need to set the DATABASE_URL environment variable

Grab the URI and then set it locally:

```shell script
heroku config:get DATABASE_URL
```

Result:

You have something like that:

<pre>
postgres://foo:bar@c2-174-129-253-104.compute-1.amazonaws.com:5432/delgun3gpebb0
</pre>

```shell script
export DATABASE_URL=postgres://foo:bar@c2-174-129-253-104.compute-1.amazonaws.com:5432/delgun3gpebb0
```

Then, spin up the container:

```shell script
docker run --name flask-tdd -e "PORT=8765" -p 5001:8765 registry.heroku.com/vast-refuge-42324/web
```

Result

<pre>
[2019-11-02 08:45:08 +0000] [1] [INFO] Starting gunicorn 19.9.0
[2019-11-02 08:45:08 +0000] [1] [INFO] Listening at: http://0.0.0.0:8765 (1)
[2019-11-02 08:45:08 +0000] [1] [INFO] Using worker: sync
[2019-11-02 08:45:08 +0000] [7] [INFO] Booting worker with pid: 7
</pre>

Navigate to [http://localhost:5001/ping](Navigate to http://localhost:5002/ping.).

You should see the following result on your browser

<pre>
{
  "status": "success",
  "message": "pong!"
}
</pre>

You can bring down the container once done:

```shell script
docker rm flask-tdd
```

Push the image to the registry

```shell script
docker push registry.heroku.com/vast-refuge-42324/web:latest
```

Release the image:

```shell script
heroku container:release web
```

Result:

<pre>
Releasing images web to vast-refuge-42324... done
</pre>

This will run the container. You should be able to view the app at [https://vast-refuge-42324.herokuapp.com/ping](https://vast-refuge-42324.herokuapp.com/ping).

How about the `users` endpoints? Do they work?

If you try the GET all users endpoint at [https://vast-refuge-42324.herokuapp.com/users](https://vast-refuge-42324.herokuapp.com/users), you should see an error:

<pre>
{"message": "Internal Server Error"}
</pre>

To view the logs, run :

```shell script
heroku logs
```

Result:

<pre>
...
sqlalchemy.exc.ProgrammingError: (psycopg2.errors.UndefinedTable) relation "users" does not exist
...
</pre>

To fix, we need to run the `recreate_db` command:

```shell script
heroku run python manage.py recreate_db
```

Result

<pre>
Running python manage.py recreate_db on ⬢ vast-refuge-42324... up, run.8683 (Free)
</pre>

Seed the DB:

```shell script
heroku run python manage.py seed_db
```

Result: 

<pre>
Running python manage.py seed_db on ⬢ vast-refuge-42324... up, run.3403 (Free)
</pre>

Test again [https://vast-refuge-42324.herokuapp.com/users](https://vast-refuge-42324.herokuapp.com/users)

You have a better result

<pre>
{"status": "success", "data": {"users": [{"id": 1, "username": "michael", "email": "hermanmu@gmail.com", "active": true}, {"id": 2, "username": "michaelherman", "email": "michael@mherman.org", "active": true}]}}
</pre>

Try to add a new user with [`HTTPie`](https://httpie.org):

install httpie using brew:

```shell script
brew install httpie
```

Now add a new user

```shell script
http --json POST https://vast-refuge-42324.herokuapp.com/users username=hello email=hello@world.com
```

Result:

<pre>
HTTP/1.1 201 CREATED
Connection: keep-alive
Content-Length: 63
Content-Type: application/json
Date: Sat, 02 Nov 2019 09:23:31 GMT
Server: gunicorn/19.9.0
Via: 1.1 vegur

{
    "message": "hello@world.com was added!",
    "status": "success"
}
</pre>


## Code Coverage and Quality

### Code Coverage

[`Code coverage`](https://en.wikipedia.org/wiki/Code_coverage) is the measure of how much code is executed during testing. By adding code coverage to your test suit, you can find areas of your code not covered by tests.

`Coverage.py` is a popular tool for measuring code coverage in Python-based applications. Now, since we're using `Pytest`, we'll integrate Coverage.py with `Pytest` using `pytest-cov`.

Add `pytest-cov` to the `requirements.txt`

```
pytest-cov==2.8.1
```

Next, we can configure the coverage reports in a `.coveragerc` file. Add this file to the project root, and then add the following config to exclude the tests from the coverage results:

```buildoutcfg
[run]
omit = project/tests/*
```

Update the containers

```shell script
docker-compose up -d --build
```

Run the tests with coverage

```shell script
docker-compose exec users pytest "project/tests" --cov="project"
```

Result

<pre>
Name                      Stmts   Miss  Cover
---------------------------------------------
project/__init__.py          16      1    94%
project/api/__init__.py       0      0   100%
project/api/models.py        14      0   100%
project/api/ping.py           8      0   100%
project/api/users.py         44      0   100%
project/config.py            12      0   100%
---------------------------------------------
TOTAL                        94      1    99%
</pre>

To see a HTML version

```shell script
docker-compose exec users pytest "project/tests" --cov="project" --cov-report html
```

The HTML version can be viewed within the newly created `htmlcov` directory. With it, you can quickly see which parts of the code are, and are not, covered by a test.

Add `htmlcov` directory and `.coverage` in the `.gitignore` and the `.dockerignore`

run the following cmd to view html result

```shell script
open htmlcov/index.html
```

> Just keep in mind that while code coverage is a good metric to look at, it does not measure the overall effectiveness of the test suite. In other words, having 100% coverage means that every line of code is being tested; it does not mean that the tests handle every scenario.
>
> In other words, just because you have 100% test coverage doesn’t mean you're testing the right things.

### Code Quality

[`Linting`](https://stackoverflow.com/questions/8503559/what-is-linting/8503586#8503586) is the process of checking your code for stylistic or programming errors. Although there are a [number](https://github.com/vintasoftware/python-linters-and-code-analysis) of commonly used linters for Python, we'll use [`Flake8`](https://gitlab.com/pycqa/flake8) since it combines two other popular linters -- [`pep8`](https://pypi.org/project/pep8/) and [`pyflakes`](https://pypi.org/project/pyflakes/).

Add flake8 to the `requirements.txt` file

```
flake8===3.7.9
```

To configure flake8, add a `setup.cfg` file to the project root

```buildoutcfg
[flake8]
max-line-length = 119
```

This sets the maximum allowed line length to 119.

Update the containers

```shell script
docker-compose up -d --build
```

Run flake8

```shell script
docker-compose exec users flake8 project
```

Result

<pre>
project/tests/functional/test_ping.py:10:39: W292 no newline at end of file
</pre>

Correct any issues

Next, let's add [`Black`](https://black.readthedocs.io/en/stable/), which is used for formatting your code so that "code looks the same regardless of the project you're reading". This helps to speed up code reviews. "Formatting becomes transparent after a while and you can focus on the content instead."

Add `black` to the `requirements.txt`

```
black==19.10b0
```

Update the containers, and then run Black:

```shell script
docker-compose up -d --build
docker-compose exec users black project --check
```

Since we used the check option, you should see the status:

<pre>
would reformat /usr/src/app/project/__init__.py
would reformat /usr/src/app/project/api/ping.py
would reformat /usr/src/app/project/config.py
would reformat /usr/src/app/project/tests/conftest.py
would reformat /usr/src/app/project/api/models.py
would reformat /usr/src/app/project/tests/functional/test_ping.py
would reformat /usr/src/app/project/tests/unit/test_config.py
would reformat /usr/src/app/project/api/users.py
would reformat /usr/src/app/project/tests/test_users.py
Oh no! 💥 💔 💥
9 files would be reformatted, 3 files would be left unchanged.
</pre>

Try running it with the diff option as well before applying the changes:

```shell script
docker-compose exec users black project --diff
```

You well see all the changes that we'll be done

```shell script
docker-compose exec users black project
```

Now the code has been automatically reformatted

Finally, let's add [`isort`](https://github.com/timothycrosley/isort) to the project as well to quickly sort all our imports alphabetically and automatically separated into sections.

Add `isort` to `requirements.txt`

```
isort==4.3.21
``` 

Rebuild, run it with the `check-only` and `diff` options:

```shell script
docker-compose up -d --build
docker-compose exec users /bin/sh -c "isort project/*/*.py" --check-only
docker-compose exec users /bin/sh -c "isort project/*/*.py" --diff
```

Then apply the changes

```shell script
docker-compose exec users /bin/sh -c "isort project/*/*.py"
```

Verify one last time that `flake8`, `Black`, and `isort` all pass:

```shell script
docker-compose exec users flake8 project
docker-compose exec users black project --check
docker-compose exec users /bin/sh -c "isort project/*/*.py" --check-only
```

## Continuous Integration

Sign in to gitlab

For the following instruction you need to create a [`personal access token`](https://github.com/settings/tokens/new) in Github

Once the personal access token is created, create a `new project`

Select `CI/CD for external repo` and select `GitHub`

Put the personal access token previously created in github

Select the project and click `connect`

Add a `.gitlab-ci.yml` to the root of the project

```yaml
image: docker:stable

stages:
  - build
  - test

variables:
  IMAGE: ${CI_REGISTRY}/${CI_PROJECT_NAMESPACE}/${CI_PROJECT_NAME}

build:
  stage: build
  services:
    - docker:dind
  variables:
    DOCKER_DRIVER: overlay2
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_JOB_TOKEN $CI_REGISTRY
    - docker pull $IMAGE:latest || true
    - docker build
        --cache-from $IMAGE:latest
        --tag $IMAGE:latest
        --file ./Dockerfile.prod
        "."
    - docker push $IMAGE:latest

test:
  stage: test
  image: $IMAGE:latest
  services:
    - postgres:latest
  variables:
    POSTGRES_DB: users
    POSTGRES_USER: runner
    POSTGRES_PASSWORD: ""
    DATABASE_TEST_URL: postgres://runner@postgres:5432/users
  script:
    - pytest "project/tests" -p no:warnings
    - flake8 project
    - black project --check
    - isort project/**/*.py --check-only
```

we defined two stages, `build` and `test`.

In the `build` stage, we:

1. Log in to the [`GitLab Container Registry`](https://docs.gitlab.com/ee/user/packages/container_registry/index.html)
2. Pull the previously pushed image (if it exists)
3. Build and tag the new image
4. Push the image up to the GitLab Container Registry

Using the image that created in the build stage along with the Postgres service, we run `Pytest`, `flake8`, `Black`, and `isort` in the `test` stage.

Once done, add the GitLab CI status badge:

<pre>
[![pipeline status](https://gitlab.com/johndoe-dev-tdd/flask-tdd-docker/badges/master/pipeline.svg)](https://gitlab.com/johndoe-dev-tdd/flask-tdd-docker/commits/master)
</pre>


## Continuous Delivery

Find your [`Heroku auth token`](https://devcenter.heroku.com/articles/authentication)

```shell script
heroku auth:token
```

To create a long-term token, use:

```shell script
heroku authorizations:create
```

Save the token as a new variable called `HEROKU_AUTH_TOKEN` within your project's CI/CD settings: Settings > CI / CD > Variables

Now, add a new deploy stage to the GitLab config file `.gitlab-ci.yml`:

```yaml
stages:
  - build
  - test
  - deploy

...

deploy:
  stage: deploy
  services:
    - docker:dind
  variables:
    DOCKER_DRIVER: overlay2
    HEROKU_APP_NAME: vast-refuge-42324
    HEROKU_REGISTRY_IMAGE: registry.heroku.com/${HEROKU_APP_NAME}/web
  script:
    - apk add --no-cache curl
    - docker build
        --tag $HEROKU_REGISTRY_IMAGE
        --file ./Dockerfile.prod
        "."
    - docker login -u _ -p $HEROKU_AUTH_TOKEN registry.heroku.com
    - docker push $HEROKU_REGISTRY_IMAGE
    - chmod +x ./release.sh
    - ./release.sh
```

Add `release.sh` to the project root

```shell script
#!/bin/sh


IMAGE_ID=$(docker inspect ${HEROKU_REGISTRY_IMAGE} --format={{.Id}})
PAYLOAD='{"updates": [{"type": "web", "docker_image": "'"$IMAGE_ID"'"}]}'

curl -n -X PATCH https://api.heroku.com/apps/$HEROKU_APP_NAME/formation \
  -d "${PAYLOAD}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/vnd.heroku+json; version=3.docker-releases" \
  -H "Authorization: Bearer ${HEROKU_AUTH_TOKEN}"
```

In the `deploy` stage, we:

1. Install cURL
2. Build and tag the new image
3. Log in to the Heroku Container Registry
4. Push the image up to the registry
5. Create a new release via the Heroku API using the image ID within the `release.sh` script (Before, we use `chmod +x` to avoid __`permission denied`__)

To test, make a quick change to the `Ping` get route by removing the explanation point ( `!` ):

Commit your code and again push it up. Your app should be auto deployed to Heroku! Navigate to:

[https://vast-refuge-42324.herokuapp.com/ping](https://vast-refuge-42324.herokuapp.com/ping)

You should see:

<pre>
{
  "status": "success",
  "message": "pong"
}
</pre>

## Remaining routes

Endpoint | HTTP Method | CRUD Method | Result
--- | --- | --- | ---
/users | GET | READ | get all users
/users/:id | GET | READ | get a single user
/users | POST | CREATE | add a user
/users/:id | PUT | UPDATE | update a user
/users/:id | DELETE | DELETE | delete a user

### DELETE

Add the following tests to `test_users.py` in `project/tests`:

```python
def test_remove_user(test_app, test_database):
    recreate_db()
    user = add_user("user-to-be-removed", "remove-me@testdriven.io")
    client = test_app.test_client()
    resp_one = client.get("/users")
    data = json.loads(resp_one.data.decode())
    assert resp_one.status_code == 200
    assert len(data["data"]["users"]) == 1
    resp_two = client.delete(f"/users/{user.id}")
    data = json.loads(resp_two.data.decode())
    assert resp_two.status_code == 200
    assert 'remove-me@testdriven.io was removed!' in data['message']
    assert 'success' in data['status']
    resp_three = client.get("/users")
    data = json.loads(resp_three.data.decode())
    assert resp_three.status_code == 200
    assert len(data["data"]["users"]) == 0


def test_remove_user_incorrect_id(test_app, test_database):
    client = test_app.test_client()
    resp = client.delete("/users/999")
    data = json.loads(resp.data.decode())
    assert resp.status_code == 404
    assert "User does not exist" in data["message"]
    assert "fail" in data["status"]
```

Run the tests to ensure they both fail

```shell script
docker-compose exec users pytest "project/tests" 
```

Then add the route handler to the `Users` class in `project/api/users.py`:

```python
def delete(self, user_id):
    response_object = {"status": "fail", "message": "User does not exist"}
    try:
        user = User.query.filter_by(id=int(user_id)).first()
        if not user:
            return response_object, 404
        else:
            db.session.delete(user)
            db.session.commit()
            response_object["status"] = "success"
            response_object["message"] = f"{user.email} was removed!"
            return response_object, 200
    except ValueError:
        return response_object, 404
```

Ensure the tests pass:

```shell script
docker-compose exec users pytest "project/tests"
```

### PUT

Start with some tests:

```python
def test_update_user(test_app, test_database):
    user = add_user("user-to-be-updated", "update-me@testdriven.io")
    client = test_app.test_client()
    resp_one = client.put(
        f"/users/{user.id}",
        data=json.dumps({"username": "me", "email": "me@testdriven.io"}),
        content_type="application/json",
    )
    data = json.loads(resp_one.data.decode())
    assert resp_one.status_code == 200
    assert f"{user.id} was updated!" in data["message"]
    assert "success" in data["status"]
    resp_two = client.get(f"/users/{user.id}")
    data = json.loads(resp_two.data.decode())
    assert resp_two.status_code == 200
    assert "me" in data["data"]["username"]
    assert "me@testdriven.io" in data["data"]["email"]
    assert "success" in data["status"]


def test_update_user_invalid_json(test_app, test_database):
    client = test_app.test_client()
    resp = client.put(
        "/users/1",
        data=json.dumps({}),
        content_type="application/json",
    )
    data = json.loads(resp.data.decode())
    assert resp.status_code == 400
    assert "Invalid payload." in data["message"]
    assert "fail" in data["status"]


def test_update_user_invalid_json_keys(test_app, test_database):
    client = test_app.test_client()
    resp = client.put(
        "/users/1",
        data=json.dumps({"email": "me@testdriven.io"}),
        content_type="application/json",
    )
    data = json.loads(resp.data.decode())
    assert resp.status_code == 400
    assert "Invalid payload." in data["message"]
    assert "fail" in data["status"]


def test_update_user_does_not_exist(test_app, test_database):
    client = test_app.test_client()
    resp = client.put(
        "/users/999",
        data=json.dumps({"username": "me", "email": "me@testdriven.io"}),
        content_type="application/json",
    )
    data = json.loads(resp.data.decode())
    assert resp.status_code == 404
    assert "User does not exist" in data["message"]
    assert "fail" in data["status"]
```

Ensure the tests fail:

```shell script
docker-compose exec users pytest "project/tests"
```

Add the route

```python
def put(self, user_id):
    post_data = request.get_json()
    response_object = {"status": "fail", "message": "Invalid payload."}
    if not post_data:
        return response_object, 400
    username = post_data.get("username")
    email = post_data.get("email")
    if not username or not email:
        return response_object, 400
    try:
        user = User.query.filter_by(id=int(user_id)).first()
        if user:
            user.username = username
            user.email = email
            db.session.commit()
            response_object["status"] = "success"
            response_object["message"] = f"{user.id} was updated!"
            return response_object, 200
        else:
            response_object["message"] = "User does not exist."
            return response_object, 404
    except exc.IntegrityError:
        db.session.rollback()
        return response_object, 400
```

Now the tests should pass:

```shell script
docker-compose exec users pytest "project/tests"
```

### Tests

Now all the tests pass, run `flake8`, `Black`, and `isort`:

```shell script
docker-compose exec users flake8 project
docker-compose exec users black project
docker-compose exec users /bin/sh -c "isort project/*/*.py"
```

We can trigger a new build by commit and push.

Once the deploy is complete, test all the routes with `HTTPie`

GET all users:

```shell script
http GET https://vast-refuge-42324.herokuapp.com/users
``` 

GET single user:

```shell script
http GET https://vast-refuge-42324.herokuapp.com/users/1
```

POST:

```shell script
http --json POST https://vast-refuge-42324.herokuapp.com/users username=someone email=someone@something.com
```

PUT:

```shell script
http --json PUT https://vast-refuge-42324.herokuapp.com/users/3 username=foo email=foo@bar.com
```

DELETE:

```shell script
http DELETE https://vast-refuge-42324.herokuapp.com/users/4
```

Finally, test our test coverage

```shell script
docker-compose exec users pytest "project/tests" --cov="project"
```