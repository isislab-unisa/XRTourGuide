from allauth.socialaccount.adapter import DefaultSocialAccountAdapter

class CustomSocialAccountAdapter(DefaultSocialAccountAdapter):
    def populate_user(self, request, sociallogin, data):
        user = super().populate_user(request, sociallogin, data)
        user.first_name = data.get('first_name', '')
        user.last_name = data.get('last_name', '')
        user.email = (
            data.get('email')
            or sociallogin.account.extra_data.get('email')
            or ''
        )
        return user

    def save_user(self, request, sociallogin, form=None):
        user = super().save_user(request, sociallogin, form)
        if not user.is_staff:
            user.is_staff = True
            user.save()
        return user
