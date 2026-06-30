import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/app_state.dart';
import 'screens/ventas_screen.dart';
import 'screens/stock_screen.dart';
import 'screens/resumen_screen.dart';
import 'screens/historial_screen.dart';
import 'screens/config_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Lock to landscape for tablet use
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF3E2009),
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const CafeApp(),
    ),
  );
}

class CafeApp extends StatelessWidget {
  const CafeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Café al Paso',
    theme: AppTheme.theme,
    debugShowCheckedModeBanner: false,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('es')],
    home: const _Shell(),
  );
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _idx = 0;

  static const _screens = [
    VentasScreen(),
    StockScreen(),
    ResumenScreen(),
    HistorialScreen(),
    ConfigScreen(),
  ];

  static const _labels = ['Ventas', 'Stock', 'Resumen', 'Historial', 'Config'];
  static const _icons = [
    Icons.point_of_sale_outlined,
    Icons.inventory_2_outlined,
    Icons.bar_chart_outlined,
    Icons.receipt_long_outlined,
    Icons.tune_outlined,
  ];
  static const _activeIcons = [
    Icons.point_of_sale,
    Icons.inventory_2,
    Icons.bar_chart,
    Icons.receipt_long,
    Icons.tune,
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.isLoading) return const _LoadingScreen();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('☕  Café al Paso'),
            const Spacer(),
            // Quick total in app bar
            if (state.ventas.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '\$${_formatShort(state.totalRecaudado)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _idx,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: List.generate(5, (i) => NavigationDestination(
          icon: Icon(_icons[i]),
          selectedIcon: Icon(_activeIcons[i], color: AppTheme.caramel),
          label: _labels[i],
        )),
      ),
    );
  }

  String _formatShort(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return '$value';
  }
}

// ── Pantalla de carga inicial ─────────────────────────────────────────────────

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.brownDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '☕',
              style: TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 24),
            const Text(
              'Café al Paso',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withAlpha(180),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
