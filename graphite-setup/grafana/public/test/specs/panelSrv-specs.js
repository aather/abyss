/*! grafana - v2.5.0 - 2015-10-28
 * Copyright (c) 2015 Torkel Ödegaard; Licensed Apache-2.0 */

define(["./helpers","app/features/panel/panelSrv"],function(){"use strict";describe("PanelSrv",function(){var a,b,c;beforeEach(module("grafana.services")),beforeEach(module(function(a){c={getMetricSources:sinon.spy()},a.value("datasourceSrv",c)})),beforeEach(inject(function(c,d){a=c,b=d.$new(),b.panel={targets:[]},b.dashboardViewState={registerPanel:sinon.spy()}})),describe("init",function(){beforeEach(function(){a.init(b)})})})});