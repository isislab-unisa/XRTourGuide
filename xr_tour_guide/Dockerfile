FROM python:3.12

WORKDIR /workspace

COPY . .

RUN apt-get update && \
    apt-get install -y default-libmysqlclient-dev build-essential && \
    pip install -r requirements.txt

RUN apt-get update && \
apt-get install -y ca-certificates && \
update-ca-certificates

RUN pip install gunicorn

EXPOSE 8001

CMD sh -c "python manage.py makemigrations && python manage.py migrate && python manage.py init_social_apps && python manage.py init_groups && python manage.py collectstatic --noinput && gunicorn --bind 0.0.0.0:8001 xr_tour_guide.wsgi:application"
# python manage.py init_groups && python manage.py seed_initial_data