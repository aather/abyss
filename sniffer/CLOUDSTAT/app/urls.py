from django.conf.urls import patterns, url

from app import views

urlpatterns = patterns('',
   url(r'^startThread/(?P<switch>\d+)/$', views.startThread, name='startThread'),
  #
  url(r'^startCapturing/', views.startCapturing, name='startCapturing')
)