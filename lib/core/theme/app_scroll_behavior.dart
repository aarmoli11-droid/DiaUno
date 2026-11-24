import 'package:flutter/material.dart';

/// Evita el rebote/estiramiento del contenido al llegar al final de una lista.
///
/// El comportamiento por defecto depende de la plataforma: en web y iOS el
/// overscroll puede deformar la pantalla y los componentes. DíaUno usa un
/// comportamiento coherente en todas partes.
class DiaUnoScrollBehavior extends ScrollBehavior {
  const DiaUnoScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}
