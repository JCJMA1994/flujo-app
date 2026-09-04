import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/di/injection.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/usecases/usecases.dart';
import '../../../transactions/presentation/widgets/transaction_form_sheet.dart';
import '../../domain/services/sunat_qr_parser.dart';

/// Hoja interactiva con cámara integrada para escanear códigos QR de boletas y facturas físicas (SUNAT / efectivo).
class QrScannerSheet extends StatefulWidget {
  const QrScannerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: Colors.transparent,
      builder: (_) => const QrScannerSheet(),
    );
  }

  @override
  State<QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<QrScannerSheet>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _scannerController;
  late final AnimationController _animController;
  final _parser = const SunatQrParser();

  SunatReceiptData? _detectedReceipt;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _detectedReceipt != null) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        final parsed = _parser.parse(raw);
        if (parsed != null) {
          HapticFeedback.mediumImpact();
          setState(() {
            _detectedReceipt = parsed;
          });
          return;
        }
      }
    }
  }

  Future<void> _registerDirectly(SunatReceiptData data) async {
    setState(() => _isProcessing = true);
    final tx = Transaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      amount: data.totalAmount,
      currency: 'PEN',
      merchant: data.merchantSuggested,
      occurredAt: data.date ?? DateTime.now(),
      category: data.suggestedCategory,
      source: TransactionSource.manual,
      scope: TransactionScope.personal,
      parser: 'sunat_qr',
    );

    await getIt<AddTransaction>()(tx);
    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🧾 Registrado: S/ ${data.totalAmount.toStringAsFixed(2)} en ${data.merchantSuggested}',
        ),
        backgroundColor: const Color(0xFF0D9488),
      ),
    );
  }

  void _editInForm(SunatReceiptData data) {
    Navigator.of(context).pop();
    final prefilled = Transaction(
      id: '',
      amount: data.totalAmount,
      currency: 'PEN',
      merchant: data.merchantSuggested,
      occurredAt: data.date ?? DateTime.now(),
      category: data.suggestedCategory,
      source: TransactionSource.manual,
      scope: TransactionScope.personal,
      parser: 'sunat_qr',
    );
    TransactionFormSheet.show(context, prefilled);
  }

  void _showManualInputDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pegar contenido QR'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Ej: 20100070970|03|B001|00001234|5.40|35.40|...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final parsed = _parser.parse(controller.text);
              if (parsed != null) {
                setState(() => _detectedReceipt = parsed);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No se reconoció un formato válido de boleta SUNAT'),
                  ),
                );
              }
            },
            child: const Text('Interpretar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2DD4BF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFF0D9488),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Escanear Boleta o Factura',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Pagos en efectivo SUNAT',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.flash_on_rounded),
                  tooltip: 'Flash',
                  onPressed: () => _scannerController.toggleTorch(),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Contenido principal: Visor de cámara o resultado detectado
          Expanded(
            child: _detectedReceipt != null
                ? _ReceiptConfirmationView(
                    receipt: _detectedReceipt!,
                    isLoading: _isProcessing,
                    onConfirm: () => _registerDirectly(_detectedReceipt!),
                    onEdit: () => _editInForm(_detectedReceipt!),
                    onScanAgain: () => setState(() => _detectedReceipt = null),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: MobileScanner(
                          controller: _scannerController,
                          onDetect: _onDetect,
                        ),
                      ),

                      // Overlay semitransparente con marco de escaneo
                      _ScannerViewfinder(animation: _animController),

                      // Mensaje orientador en la parte inferior
                      Positioned(
                        bottom: 24,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.receipt_long_rounded,
                                color: Color(0xFF2DD4BF),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Apunta al código QR impreso en el ticket o boleta',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _showManualInputDialog,
                                child: const Text(
                                  'Pegar texto',
                                  style: TextStyle(
                                    color: Color(0xFF2DD4BF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScannerViewfinder extends StatelessWidget {
  const _ScannerViewfinder({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = (constraints.maxWidth * 0.72).clamp(220.0, 300.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: boxSize,
              height: boxSize,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF2DD4BF).withValues(alpha: 0.8),
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2DD4BF).withValues(alpha: 0.2),
                    blurRadius: 16,
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                return Positioned(
                  top: (constraints.maxHeight - boxSize) / 2 +
                      (boxSize * animation.value),
                  child: Container(
                    width: boxSize - 16,
                    height: 2,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0xFF2DD4BF),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _ReceiptConfirmationView extends StatelessWidget {
  const _ReceiptConfirmationView({
    required this.receipt,
    required this.isLoading,
    required this.onConfirm,
    required this.onEdit,
    required this.onScanAgain,
  });

  final SunatReceiptData receipt;
  final bool isLoading;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF0D9488),
              size: 56,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '¡Comprobante Detectado!',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            receipt.documentType,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Tarjeta de datos extraídos
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total a Registrar',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      Text(
                        'S/ ${receipt.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.store_rounded, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          receipt.merchantSuggested,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.tag_rounded, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        '${receipt.suggestedCategory.emoji} ${receipt.suggestedCategory.name}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      if (receipt.serialNumber.isNotEmpty) ...[
                        const Spacer(),
                        Text(
                          receipt.serialNumber,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Botones de acción
          FilledButton.icon(
            onPressed: isLoading ? null : onConfirm,
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('Registrar Gasto en Efectivo'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onScanAgain,
                  child: const Text('Escanear otro'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: onEdit,
                  child: const Text('Editar detalles'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
