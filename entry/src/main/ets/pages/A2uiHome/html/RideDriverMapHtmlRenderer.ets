type RideMapTextValue = Object | string | number | boolean | null | undefined;

export interface RideDriverMapHtmlOptions {
  routeText: string;
  pickupLocation: string;
  driverLocation: string;
  driverName: string;
  etaText: string;
  amapKey: string;
  amapSecurityJsCode: string;
}

interface RideLngLat {
  lng: string;
  lat: string;
}

function textOf(value: RideMapTextValue): string {
  if (value === null || value === undefined) {
    return '';
  }
  return String(value);
}

function htmlEscape(value: RideMapTextValue): string {
  return textOf(value)
    .split('&').join('&amp;')
    .split('<').join('&lt;')
    .split('>').join('&gt;')
    .split('"').join('&quot;')
    .split("'").join('&#39;');
}

function jsonString(value: RideMapTextValue): string {
  return JSON.stringify(textOf(value));
}

function parseLngLat(location: string): RideLngLat {
  const parts = location.split(',');
  return {
    lng: parts.length > 0 ? parts[0].trim() : '',
    lat: parts.length > 1 ? parts[1].trim() : ''
  };
}

function hasLngLat(location: string): boolean {
  return /^-?\d+(?:\.\d+)?,\s*-?\d+(?:\.\d+)?$/.test(location.trim());
}

function amapScriptUrl(amapKey: string): string {
  return 'https://webapi.amap.com/maps?v=2.0&key=' + encodeURIComponent(amapKey);
}

export function renderRideDriverMapHtml(options: RideDriverMapHtmlOptions): string {
  const pickup = parseLngLat(options.pickupLocation);
  const driver = parseLngLat(options.driverLocation);
  const canLoadMap = options.amapKey.trim().length > 0 &&
    hasLngLat(options.pickupLocation) &&
    hasLngLat(options.driverLocation);
  const rawEtaText = options.etaText.trim();
  const etaText = rawEtaText.indexOf('预计') >= 0 ? rawEtaText : '正在估算接驾时间';
  const routeText = options.routeText.trim().length > 0 ? options.routeText.trim() : '司机前往上车点';
  const driverName = options.driverName.trim().length > 0 ? options.driverName.trim() : '司机';
  const securityScript = options.amapSecurityJsCode.trim().length > 0 ?
    'window._AMapSecurityConfig={securityJsCode:' + jsonString(options.amapSecurityJsCode) + '};' : '';
  const scriptTag = canLoadMap ? '<script src="' + amapScriptUrl(options.amapKey.trim()) + '"></script>' : '';

  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
  <title>司机位置</title>
  <style>
    * { box-sizing: border-box; }
    body { margin: 0; min-height: 100vh; background: #f5e9dd; color: #211b17; font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", Arial, sans-serif; letter-spacing: 0; overflow: hidden; }
    #map { position: absolute; inset: 0; background: linear-gradient(135deg, #f0d9c4, #f8efe6); }
    .fallback { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; padding: 20px; background: linear-gradient(135deg, #f0d9c4, #f8efe6); }
    .fallback-card { width: 100%; border: 1px solid rgba(181,101,77,.18); border-radius: 20px; padding: 18px; background: rgba(255,252,247,.9); box-shadow: 0 12px 28px rgba(95,54,35,.12); }
    .fallback-card h1 { margin: 0; font-size: 17px; line-height: 22px; color: #7d3e31; }
    .fallback-card p { margin: 8px 0 0; font-size: 13px; line-height: 19px; color: #493f38; }
    .marker { display: inline-flex; align-items: center; justify-content: center; height: 30px; padding: 0 10px; border-radius: 15px; color: #fff; font-size: 12px; font-weight: 850; box-shadow: 0 8px 20px rgba(0,0,0,.18); white-space: nowrap; }
    .marker-driver { background: #5f6f86; }
    .marker-pickup { background: #b5654d; }
  </style>
  <script>${securityScript}</script>
  ${scriptTag}
</head>
<body>
  <div id="map"></div>
  <div class="fallback" id="fallback" style="${canLoadMap ? 'display:none' : ''}">
    <div class="fallback-card">
      <h1>${htmlEscape(etaText)}</h1>
      <p>${htmlEscape(routeText)}</p>
      <p>司机：${htmlEscape(driverName)}</p>
      <p>上车点：${htmlEscape(options.pickupLocation)} · 司机：${htmlEscape(options.driverLocation)}</p>
    </div>
  </div>
  <script>
    (function () {
      var canLoadMap = ${canLoadMap ? 'true' : 'false'};
      var pickup = [${jsonString(pickup.lng)}, ${jsonString(pickup.lat)}];
      var driver = [${jsonString(driver.lng)}, ${jsonString(driver.lat)}];
      function showFallback() {
        var fallback = document.getElementById('fallback');
        if (fallback) { fallback.style.display = 'flex'; }
      }
      function markerContent(label, className) {
        return '<div class="marker ' + className + '">' + label + '</div>';
      }
      function formatDuration(seconds) {
        var minute = Math.max(1, Math.round(Number(seconds || 0) / 60));
        return '预计 ' + minute + ' 分钟接驾';
      }
      function routeCostDuration(route) {
        if (!route) { return 0; }
        var cost = route.cost || {};
        return Number(cost.duration || route.duration || 0);
      }
      function textValue(value) {
        if (value === null || value === undefined) { return ''; }
        return String(value);
      }
      function emitRouteLog(stage, detail) {
        var payload = { type: 'rideMapRouteLog', stage: textValue(stage), detail: detail || {} };
        try {
          if (window.console && typeof window.console.log === 'function') {
            window.console.log('[AIPhone][RideMapRoute] ' + payload.stage, payload.detail);
          }
        } catch (error) {
        }
        try {
          if (window.AIPhoneRideMap && typeof window.AIPhoneRideMap.postMessage === 'function') {
            window.AIPhoneRideMap.postMessage(JSON.stringify(payload));
          }
        } catch (error) {
        }
        try {
          if (window.parent && window.parent !== window) {
            window.parent.postMessage(payload, '*');
          }
        } catch (error) {
        }
      }
      function emitEta(value) {
        try {
          if (window.parent && window.parent !== window) {
            window.parent.postMessage({ type: 'rideMapEta', etaText: value }, '*');
          }
        } catch (error) {
        }
      }
      function routePathFromStep(step) {
        var path = [];
        if (!step) { return path; }
        var source = pathPolyline(step);
        if (typeof source === 'string' && source.length > 0) {
          var pairs = source.split(';');
          for (var i = 0; i < pairs.length; i += 1) {
            var parts = pairs[i].split(',');
            if (parts.length >= 2) {
              path.push(new AMap.LngLat(Number(parts[0]), Number(parts[1])));
            }
          }
        } else if (source && source.length) {
          for (var j = 0; j < source.length; j += 1) {
            path.push(source[j]);
          }
        }
        if (step.tmcs && step.tmcs.length) {
          for (var k = 0; k < step.tmcs.length; k += 1) {
            var tmcPath = routePathFromStep(step.tmcs[k]);
            for (var m = 0; m < tmcPath.length; m += 1) {
              path.push(tmcPath[m]);
            }
          }
        }
        return path;
      }
      function pathPolyline(step) {
        if (!step) { return ''; }
        return step.path || step.polyline || '';
      }
      function plannedPathFromRoute(route) {
        var path = [];
        if (!route || !route.steps || !route.steps.length) { return path; }
        for (var i = 0; i < route.steps.length; i += 1) {
          var stepPath = routePathFromStep(route.steps[i]);
          if (!stepPath.length) { continue; }
          for (var j = 0; j < stepPath.length; j += 1) {
            path.push(stepPath[j]);
          }
        }
        return path;
      }
      function init() {
        if (!canLoadMap || !window.AMap) {
          emitRouteLog('map_unavailable', {
            canLoadMap: canLoadMap,
            hasAMap: !!window.AMap,
            hasKey: ${options.amapKey.trim().length > 0 ? 'true' : 'false'},
            pickup: pickup.join(','),
            driver: driver.join(',')
          });
          showFallback();
          emitEta(${jsonString(etaText)});
          return;
        }
        if (window.rideMapRouteCallback && window.rideMapRouteCallback.__script) {
          try { window.rideMapRouteCallback.__script.remove(); } catch (error) {}
        }
        var map = new AMap.Map('map', { zoom: 14, resizeEnable: true, viewMode: '2D' });
        var pickupLngLat = new AMap.LngLat(Number(pickup[0]), Number(pickup[1]));
        var driverLngLat = new AMap.LngLat(Number(driver[0]), Number(driver[1]));
        var pickupMarker = new AMap.Marker({ map: map, position: pickupLngLat, content: markerContent('上车点', 'marker-pickup'), anchor: 'bottom-center', zIndex: 20 });
        var driverMarker = new AMap.Marker({ map: map, position: driverLngLat, content: markerContent('司机', 'marker-driver'), anchor: 'bottom-center', zIndex: 20 });
        map.setFitView([pickupMarker, driverMarker], false, [22, 22, 22, 22]);
        try {
          var script = document.createElement('script');
          var routeApiUrl = 'https://restapi.amap.com/v5/direction/driving?key=' +
            encodeURIComponent(${jsonString(options.amapKey.trim())}) +
            '&origin=' + encodeURIComponent(driver.join(',')) +
            '&destination=' + encodeURIComponent(pickup.join(',')) +
            '&strategy=38&show_fields=cost,polyline&callback=rideMapRouteCallback';
          emitRouteLog('search_start', {
            pickup: pickup.join(','),
            driver: driver.join(','),
            api: 'amap_webservice_v5_direction_driving',
            strategy: '38'
          });
          window.rideMapRouteCallback = function (result) {
            var routeGroup = result && result.route ? result.route : null;
            var paths = routeGroup && routeGroup.paths ? routeGroup.paths : [];
            var routes = paths;
            var route = routes.length > 0 ? routes[0] : null;
            var summary = {
              status: textValue(result && result.status),
              info: textValue(result && result.info),
              infocode: textValue(result && result.infocode),
              routesLength: routes.length,
              routeTimeSeconds: routeCostDuration(route),
              routeDistanceMeters: route ? Number(route.distance || 0) : 0
            };
            if (result && result.status === '1' && route) {
              var plannedPath = plannedPathFromRoute(route);
              summary.plannedPathPoints = plannedPath.length;
              if (plannedPath.length > 1) {
                var routeLine = new AMap.Polyline({
                  map: map,
                  path: plannedPath,
                  strokeColor: '#b5654d',
                  strokeWeight: 7,
                  strokeOpacity: 0.82,
                  strokeStyle: 'solid',
                  lineJoin: 'round',
                  lineCap: 'round',
                  zIndex: 8
                });
                map.setFitView([pickupMarker, driverMarker, routeLine], false, [22, 22, 22, 22]);
              }
              summary.etaText = formatDuration(summary.routeTimeSeconds);
              emitRouteLog('search_complete', summary);
              emitEta(summary.etaText);
            } else {
              summary.fallbackEtaText = ${jsonString(etaText)};
              emitRouteLog('search_fallback', summary);
              emitEta(${jsonString(etaText)});
            }
          };
          window.rideMapRouteCallback.__script = script;
          script.onerror = function () {
            emitRouteLog('search_error', {
              message: 'amap_webservice_jsonp_load_error',
              pickup: pickup.join(','),
              driver: driver.join(',')
            });
            emitEta(${jsonString(etaText)});
          };
          script.src = routeApiUrl;
          document.head.appendChild(script);
        } catch (error) {
          emitRouteLog('search_error', {
            message: textValue(error && (error.message || error.name || error)),
            pickup: pickup.join(','),
            driver: driver.join(',')
          });
          emitEta(${jsonString(etaText)});
        }
      }
      if (document.readyState === 'complete') { init(); } else { window.addEventListener('load', init); }
    })();
  </script>
</body>
</html>`;
}
