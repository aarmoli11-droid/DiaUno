/// Errores de dominio con mensajes seguros para mostrar al usuario.
sealed class AppFailure implements Exception {
  const AppFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message) : super(code: 'validation');
}

class AuthFailure extends AppFailure {
  const AuthFailure(super.message, {super.code = 'auth'});
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([
    super.message = 'Sin conexión. Los cambios quedarán pendientes.',
  ]) : super(code: 'network');
}

class ServerFailure extends AppFailure {
  const ServerFailure(super.message, {super.code = 'server'});
}

class PermissionFailure extends AppFailure {
  const PermissionFailure([
    super.message = 'No tienes permiso para realizar esta acción.',
  ]) : super(code: 'permission');
}

class ConflictFailure extends AppFailure {
  const ConflictFailure([
    super.message = 'Este elemento cambió en otro dispositivo.',
  ]) : super(code: 'conflict');
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'No encontramos ese elemento.'])
    : super(code: 'not_found');
}

AppFailure mapPostgrestError(Object error, [String? rawMessage]) {
  final text = (rawMessage ?? error.toString()).toLowerCase();
  if (text.contains('jwt') || text.contains('auth')) {
    return AuthFailure('Tu sesión no es válida. Vuelve a iniciar sesión.');
  }
  if (text.contains('permission denied') ||
      text.contains('row-level security')) {
    return const PermissionFailure();
  }
  if (text.contains('duplicate') || text.contains('unique')) {
    return const ServerFailure('Ya existe un registro con esos datos.');
  }
  if (text.contains('socket') ||
      text.contains('connection') ||
      text.contains('timeout')) {
    return const NetworkFailure();
  }
  return ServerFailure(
    'No se pudo completar la operación. Inténtalo de nuevo.',
  );
}
