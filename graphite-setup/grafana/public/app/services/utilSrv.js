/*! grafana - v2.5.0 - 2015-10-28
 * Copyright (c) 2015 Torkel Ödegaard; Licensed Apache-2.0 */

define(["angular"],function(a){"use strict";var b=a.module("grafana.services");b.service("utilSrv",["$rootScope","$modal","$q",function(a,b,c){this.init=function(){a.onAppEvent("show-modal",this.showModal,a)},this.showModal=function(a,d){var e=b({modalClass:d.modalClass,template:d.src,persist:!1,show:!1,scope:d.scope,keyboard:!1});c.when(e).then(function(a){a.modal("show")})}}])});