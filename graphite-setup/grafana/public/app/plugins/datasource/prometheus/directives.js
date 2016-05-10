/*! grafana - v2.5.0 - 2015-10-28
 * Copyright (c) 2015 Torkel Ödegaard; Licensed Apache-2.0 */

define(["angular"],function(a){"use strict";var b=a.module("grafana.directives");b.directive("metricQueryEditorPrometheus",function(){return{controller:"PrometheusQueryCtrl",templateUrl:"app/plugins/datasource/prometheus/partials/query.editor.html"}})});