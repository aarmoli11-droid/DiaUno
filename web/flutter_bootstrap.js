// Bootstrap personalizado de Flutter Web.
// Se omite serviceWorkerSettings a proposito: el service worker de Flutter esta
// obsoleto en esta version, se desregistra solo y provoca una recarga que deja
// la aplicacion en blanco durante la inicializacion.
{{flutter_js}}

{{flutter_build_config}}

_flutter.loader.load({});
