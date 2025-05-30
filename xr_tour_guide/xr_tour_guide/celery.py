from __future__ import absolute_import, unicode_literals
import os
from celery import Celery

from datetime import timedelta

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'xr_tour_guide.settings')

app = Celery('xr_tour_guide')
app.config_from_object('django.conf:settings', namespace='CELERY')

app.autodiscover_tasks(lambda: ['xr_tour_guide'])

app.conf.task_queues = {
    'api_tasks': {
        'exchange': 'api_tasks',
        'routing_key': 'api_tasks',
    }
}

app.conf.beat_schedule = {
    'fail-stuck-builds': {
        'task': 'xr_tour_guide.tasks.fail_stuck_builds',
        'schedule': timedelta(minutes=10),
    },
}

# docker-compose exec web celery -A xr_tour_guide.celery worker -Q api_tasks --concurrency=1 --loglevel=info