/*! grafana - v2.5.0 - 2015-10-28
 * Copyright (c) 2015 Torkel Ödegaard; Licensed Apache-2.0 */

define(["angular","lodash"],function(a){"use strict";var b=a.module("grafana.controllers");b.controller("JsonEditorCtrl",["$scope",function(b){b.json=a.toJson(b.object,!0),b.canUpdate=void 0!==b.updateHandler,b.update=function(){var c=a.fromJson(b.json);b.updateHandler(c,b.object)}}])});