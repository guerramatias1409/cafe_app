# ☕ Café al Paso – App Flutter

App de gestión de ventas y stock para tablet Android.

## Requisitos

- Flutter SDK ≥ 3.0.0  
  → https://docs.flutter.dev/get-started/install
- Android Studio o VS Code con el plugin Flutter
- Dispositivo Android o emulador

## Instalación

```bash
# 1. Entrá a la carpeta del proyecto
cd cafe_app

# 2. Descargá las dependencias
flutter pub get

# 3. Conectá el tablet por USB (habilitá depuración USB en el dispositivo)
#    O abrí un emulador Android desde Android Studio

# 4. Corré la app
flutter run

# Para compilar el APK instalable:
flutter build apk --release
# El APK queda en: build/app/outputs/flutter-apk/app-release.apk
```

## Estructura del proyecto

```
lib/
├── main.dart                  # Entrada + navegación
├── theme.dart                 # Colores y estilos
├── models/
│   └── models.dart            # Combo, Venta, StockEntry, enums
├── providers/
│   └── app_state.dart         # Estado global + persistencia
├── screens/
│   ├── ventas_screen.dart     # Registro de ventas
│   ├── stock_screen.dart      # Stock inicial y actual
│   ├── resumen_screen.dart    # Totales del día
│   └── config_screen.dart     # Precios configurables
└── widgets/
    └── shared_widgets.dart    # Componentes reutilizables
```

## Funcionalidades

- **Ventas**: Selector de combo, cafés adicionales (0–4), medio de pago, precio calculado automáticamente. Historial de las últimas ventas con opción de deshacer.
- **Stock**: Stock inicial editable por insumo. Descuento automático al registrar ventas.
- **Resumen**: Recaudación total, desglose por medio de pago y por combo.
- **Config**: Precio del café solo y precio del café adicional editables.
- **Persistencia**: Todo se guarda en el dispositivo y se restaura al abrir la app.
