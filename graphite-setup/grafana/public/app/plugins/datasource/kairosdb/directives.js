/*! grafana - v2.5.0 - 2015-10-28
 * Copyright (c) 2015 Torkel Ödegaard; Licensed Apache-2.0 */

define(["angular"],function(a){"use strict";var b=a.module("grafana.directives");b.directive("metricQueryEditorKairosdb",function(){return{controller:"KairosDBQueryCtrl",templateUrl:"app/plugins/datasource/kairosdb/partials/query.editor.html"}}),b.directive("metricQueryOptionsKairosdb",function(){return{templateUrl:"app/plugins/datasource/kairosdb/partials/query.options.html"}})});