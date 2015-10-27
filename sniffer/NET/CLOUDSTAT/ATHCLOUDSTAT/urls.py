from django.conf.urls import patterns, include, url
from django.contrib import admin

admin.autodiscover()


# ViewSets define the view behavior.


urlpatterns = patterns('',
    # Examples:
    # url(r'^$', 'ATHCLOUDSTAT.views.home', name='home'),
    # url(r'^blog/', include('blog.urls')),

    url(r'^admin/', include(admin.site.urls)),
    url(r'^app/', include('app.urls')),
   
)
