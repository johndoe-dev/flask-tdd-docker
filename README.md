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