# pull official base image
FROM python:3.7.4-alpine

# set working directory
WORKDIR /usr/src/app

# set environment varibles
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# add and install requirements
COPY ./requirements.txt .
RUN pip install -r requirements.txt

# add app
COPY . .

# run server
EXPOSE 5000
CMD python manage.py run -h 0.0.0.0