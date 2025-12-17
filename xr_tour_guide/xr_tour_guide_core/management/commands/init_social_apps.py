# import os
# from dotenv import load_dotenv
# from django.core.management.base import BaseCommand
# from allauth.socialaccount.models import SocialApp
# from django.contrib.sites.models import Site

# load_dotenv()

# class Command(BaseCommand):
#     help = 'Inizializza le social apps (Google, Facebook)'

#     def handle(self, *args, **options):
#         site = Site.objects.get(id=2)

#         providers = [
#             {
#                 'provider': 'google',
#                 'name': 'Google',
#                 'client_id': os.getenv('GOOGLE_CLIENT_ID'),
#                 'secret': os.getenv('GOOGLE_CLIENT_SECRET'),
#             },
#             # {
#             #     'provider': 'facebook',
#             #     'name': 'Facebook',
#             #     'client_id': os.getenv('FB_APP_ID'),
#             #     'secret': os.getenv('FB_SECRET'),
#             # }
#         ]

#         for data in providers:
#             app, created = SocialApp.objects.get_or_create(
#                 provider=data['provider'],
#                 defaults={
#                     'name': data['name'],
#                     'client_id': data['client_id'],
#                     'secret': data['secret'],
#                 }
#             )

#             if not created:
#                 app.client_id = data['client_id']
#                 app.secret = data['secret']
#                 app.save()
#                 self.stdout.write(f"{data['provider']} aggiornato.")
#             else:
#                 self.stdout.write(f"{data['provider']} creato.")

#             if site not in app.sites.all():
#                 app.sites.add(site)
#                 self.stdout.write(f"Sito associato a {data['provider']}.")

#         self.stdout.write(self.style.SUCCESS("Social apps configurate."))
