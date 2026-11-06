{{flutter_js}}
{{flutter_build_config}}

// Keep the rendering engine on this origin so the cached game can start offline.
_flutter.loader.load({
  config: { canvasKitBaseUrl: 'canvaskit/' }
});
