import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tokens oficiales del Sistema de Diseño "Flujo".
class FlujoTokens {
  const FlujoTokens._();

  // Colores principales
  static const Color verdePetroleo = Color(0xFF0F766E); // Primary
  static const Color fondo = Color(0xFFF8FAFC); // Surface / Background
  static const Color texto = Color(0xFF0F172A); // On Surface / Titulares
  static const Color textoSecundario = Color(0xFF475569); // On Surface Variant
  static const Color acentoClaro = Color(0xFFCCFBF1); // Primary Container
  static const Color ambar = Color(0xFFF59E0B); // Warning / Pendientes
  static const Color crimson = Color(0xFFDC2626); // Error / Gastos

  // Métricas y layout
  static const double espaciadoBase = 8;
  static const double radioTarjetas = 20;
  static const double alturaBoton = 52;
}

const String _kThemeStorageKey = 'app_user_theme_mode';

/// Controlador persistente del modo de tema (Claro / Oscuro / Sistema).
class AppThemeController {
  const AppThemeController._();

  static final ValueNotifier<ThemeMode> notifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Carga la preferencia de tema guardada en disco.
  static Future<void> init() async {
    try {
      const storage = FlutterSecureStorage();
      final saved = await storage.read(key: _kThemeStorageKey);
      if (saved != null) {
        notifier.value = switch (saved) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
      }
    } catch (_) {}
  }

  /// Actualiza el tema en memoria y lo persiste inmediatamente.
  static Future<void> setTheme(ThemeMode mode) async {
    notifier.value = mode;
    try {
      const storage = FlutterSecureStorage();
      final value = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await storage.write(key: _kThemeStorageKey, value: value);
    } catch (_) {}
  }
}

/// Getter para mantener compatibilidad con el código existente.
ValueNotifier<ThemeMode> get appThemeModeNotifier =>
    AppThemeController.notifier;

/// Extensión semántica para colores propios del dominio de Flujo.
class FlujoColors extends ThemeExtension<FlujoColors> {
  const FlujoColors({
    required this.verdePetroleo,
    required this.acentoClaro,
    required this.ambar,
    required this.crimson,
    required this.textoSecundario,
  });

  final Color verdePetroleo;
  final Color acentoClaro;
  final Color ambar;
  final Color crimson;
  final Color textoSecundario;

  @override
  ThemeExtension<FlujoColors> copyWith({
    Color? verdePetroleo,
    Color? acentoClaro,
    Color? ambar,
    Color? crimson,
    Color? textoSecundario,
  }) {
    return FlujoColors(
      verdePetroleo: verdePetroleo ?? this.verdePetroleo,
      acentoClaro: acentoClaro ?? this.acentoClaro,
      ambar: ambar ?? this.ambar,
      crimson: crimson ?? this.crimson,
      textoSecundario: textoSecundario ?? this.textoSecundario,
    );
  }

  @override
  ThemeExtension<FlujoColors> lerp(
    ThemeExtension<FlujoColors>? other,
    double t,
  ) {
    if (other is! FlujoColors) return this;
    return FlujoColors(
      verdePetroleo:
          Color.lerp(verdePetroleo, other.verdePetroleo, t) ?? verdePetroleo,
      acentoClaro: Color.lerp(acentoClaro, other.acentoClaro, t) ?? acentoClaro,
      ambar: Color.lerp(ambar, other.ambar, t) ?? ambar,
      crimson: Color.lerp(crimson, other.crimson, t) ?? crimson,
      textoSecundario: Color.lerp(textoSecundario, other.textoSecundario, t) ??
          textoSecundario,
    );
  }
}

/// Acceso ergonómico a los tokens desde cualquier BuildContext.
extension FlujoThemeX on BuildContext {
  FlujoColors get flujoColors =>
      Theme.of(this).extension<FlujoColors>() ??
      const FlujoColors(
        verdePetroleo: FlujoTokens.verdePetroleo,
        acentoClaro: FlujoTokens.acentoClaro,
        ambar: FlujoTokens.ambar,
        crimson: FlujoTokens.crimson,
        textoSecundario: FlujoTokens.textoSecundario,
      );
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = isDark
        ? const ColorScheme.dark(
            primary: Color(0xFF2DD4BF),
            onPrimary: Color(0xFF042F2E),
            primaryContainer: FlujoTokens.verdePetroleo,
            onPrimaryContainer: FlujoTokens.acentoClaro,
            surface: Color(0xFF0F172A),
            onSurfaceVariant: Color(0xFF94A3B8),
            error: Color(0xFFF87171),
            onError: Color(0xFF450A0A),
            errorContainer: Color(0xFF7F1D1D),
            onErrorContainer: Color(0xFFFECACA),
            surfaceContainerHighest: Color(0xFF1E293B),
            outline: Color(0xFF334155),
            outlineVariant: Color(0xFF475569),
          )
        : const ColorScheme.light(
            primary: FlujoTokens.verdePetroleo,
            primaryContainer: FlujoTokens.acentoClaro,
            onPrimaryContainer: FlujoTokens.verdePetroleo,
            surface: FlujoTokens.fondo,
            onSurface: FlujoTokens.texto,
            onSurfaceVariant: FlujoTokens.textoSecundario,
            error: FlujoTokens.crimson,
            errorContainer: Color(0xFFFEE2E2),
            onErrorContainer: Color(0xFF991B1B),
            surfaceContainerHighest: Color(0xFFF1F5F9),
            outline: Color(0xFFE2E8F0),
            outlineVariant: Color(0xFFCBD5E1),
          );

    final flujoColors = isDark
        ? const FlujoColors(
            verdePetroleo: Color(0xFF2DD4BF),
            acentoClaro: Color(0xFF134E4A),
            ambar: Color(0xFFFBBF24),
            crimson: Color(0xFFF87171),
            textoSecundario: Color(0xFF94A3B8),
          )
        : const FlujoColors(
            verdePetroleo: FlujoTokens.verdePetroleo,
            acentoClaro: FlujoTokens.acentoClaro,
            ambar: FlujoTokens.ambar,
            crimson: FlujoTokens.crimson,
            textoSecundario: FlujoTokens.textoSecundario,
          );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: <ThemeExtension<dynamic>>[flujoColors],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlujoTokens.radioTarjetas),
          side: BorderSide(
            color: isDark
                ? const Color(0xFF334155)
                : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
          ),
        ),
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: scheme.primary,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 3,
      ),
    );
  }
}
