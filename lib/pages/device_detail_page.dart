import 'package:flutter/material.dart';

import '../models/seki_model.dart';
import '../widgets/seki_card.dart';

class DeviceDetailPage extends StatelessWidget {
  final Seki seki;

  const DeviceDetailPage({super.key, required this.seki});

  String get _status => seki.endYear == null ? 'Active' : 'Vintage';
  String get _period => seki.endYear == null
      ? '${seki.startYear} – Present'
      : '${seki.startYear} – ${seki.endYear}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF02081A) : const Color(0xFFF5F5F5);
    final lightGreyBg = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.grey.shade100;
    final labelColor = isDark
        ? theme.colorScheme.onSurface.withOpacity(0.5)
        : Colors.grey.shade600;
    final valueColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              // Hero Header: Icon + Device Name
              Hero(
                tag: 'device_icon_${seki.id}',
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: lightGreyBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    getIconByDeviceName(seki.deviceName),
                    size: 80,
                    color: isDark
                        ? theme.colorScheme.onSurface.withOpacity(0.8)
                        : Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Device Name
              Text(
                seki.deviceName,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Unified Info Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surface.withOpacity(0.3)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  children: [
                    _buildInfoRow('STATUS', _status, labelColor, valueColor),
                    const SizedBox(height: 20),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.colorScheme.onSurface.withOpacity(0.1),
                    ),
                    const SizedBox(height: 20),
                    _buildInfoRow('PERIOD', _period, labelColor, valueColor),
                    const SizedBox(height: 20),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: theme.colorScheme.onSurface.withOpacity(0.1),
                    ),
                    const SizedBox(height: 20),
                    _buildInfoRow('OWNER', seki.username, labelColor, valueColor),
                  ],
                ),
              ),
              // Note Section (if available)
              if (seki.note.isNotEmpty) ...[
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: RichText(
                    textAlign: TextAlign.left,
                    text: TextSpan(
                      style: TextStyle(
                        color: valueColor.withOpacity(0.85),
                        fontSize: 18,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                      ),
                      children: [
                        TextSpan(
                          text: '"',
                          style: TextStyle(
                            fontSize: 32,
                            height: 0.5,
                            color: labelColor,
                            fontFamily: 'serif',
                          ),
                        ),
                        TextSpan(text: seki.note),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    Color labelColor,
    Color valueColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
