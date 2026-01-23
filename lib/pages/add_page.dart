import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddPage extends StatefulWidget {
  final User? user;
  final VoidCallback? onNavigateToWorld;

  const AddPage({super.key, required this.user, this.onNavigateToWorld});

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _deviceType = 'Mac';
  RangeValues _yearRange = const RangeValues(2010, 2026);
  bool _stillUsing = false;

  void _clearForm() {
    _deviceNameController.clear();
    _noteController.clear();
    _deviceType = 'Mac';
    _yearRange = const RangeValues(2010, 2026);
    _stillUsing = false;
  }

  void _showSekiForm() {
    _clearForm();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => _SekiFormBottomSheet(
          deviceNameController: _deviceNameController,
          noteController: _noteController,
          deviceType: _deviceType,
          yearRange: _yearRange,
          stillUsing: _stillUsing,
          onDeviceTypeChanged: (type) {
            setState(() {
              _deviceType = type;
            });
            setModalState(() {});
          },
          onYearRangeChanged: (range) {
            setState(() {
              _yearRange = range;
            });
            setModalState(() {});
          },
          onStillUsingChanged: (value) {
            setState(() {
              _stillUsing = value;
            });
            setModalState(() {});
          },
          onSend: () async {
            if (_deviceNameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a device name')),
              );
              return;
            }
            final success = await _sendSeki(
              deviceName: _deviceNameController.text,
              deviceType: _deviceType,
              startYear: _yearRange.start.toInt(),
              endYear: _stillUsing ? null : _yearRange.end.toInt(),
              note: _noteController.text.trim(),
            );
            if (success && mounted) {
              Navigator.pop(context);
              _clearForm();
              if (widget.onNavigateToWorld != null) {
                widget.onNavigateToWorld!();
              }
            }
          },
        ),
      ),
    );
  }

  Future<bool> _sendSeki({
    required String deviceName,
    required String deviceType,
    required int startYear,
    int? endYear,
    required String note,
  }) async {
    if (widget.user == null) {
      print('ERROR: User is null, cannot send Seki');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Not signed in')),
        );
      }
      return false;
    }

    try {
      print('DEBUG: Sending Seki to seki collection');
      print('DEBUG: Device: $deviceName, Type: $deviceType');
      print('DEBUG: Years: $startYear - ${endYear ?? "Present"}');

      await FirebaseFirestore.instance.collection('seki').add({
        'uid': widget.user!.uid,
        'deviceName': deviceName.trim(),
        'deviceType': deviceType,
        'startYear': startYear,
        'endYear': endYear,
        'createdAt': FieldValue.serverTimestamp(),
        'note': note,
      });

      print('DEBUG: Seki sent successfully');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seki sent successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return true;
    } catch (e, stackTrace) {
      print('ERROR: Failed to send Seki: $e');
      print('ERROR: Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send Seki: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user == null) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF02081A),
              Color(0xFF04102C),
            ],
          ),
        ),
        child: const Center(
          child: Text(
            'Please sign in to send Seki',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF02081A),
            Color(0xFF04102C),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Send Seki',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 6,
                    ),
                  ),
                ],
              ),
            ),
            // Send Seki button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: FilledButton.icon(
                onPressed: _showSekiForm,
                icon: const Icon(Icons.send),
                label: const Text('Send Seki'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF02081A),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SekiFormBottomSheet extends StatefulWidget {
  final TextEditingController deviceNameController;
  final TextEditingController noteController;
  final String deviceType;
  final RangeValues yearRange;
  final bool stillUsing;
  final ValueChanged<String> onDeviceTypeChanged;
  final ValueChanged<RangeValues> onYearRangeChanged;
  final ValueChanged<bool> onStillUsingChanged;
  final VoidCallback onSend;

  const _SekiFormBottomSheet({
    required this.deviceNameController,
    required this.noteController,
    required this.deviceType,
    required this.yearRange,
    required this.stillUsing,
    required this.onDeviceTypeChanged,
    required this.onYearRangeChanged,
    required this.onStillUsingChanged,
    required this.onSend,
  });

  @override
  State<_SekiFormBottomSheet> createState() => _SekiFormBottomSheetState();
}

class _SekiFormBottomSheetState extends State<_SekiFormBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final deviceTypes = ['Mac', 'iPhone', 'iPad', 'iPod', 'Apple Watch', 'Vintage'];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F35),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Send Seki',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                // Device Name
                TextField(
                  controller: widget.deviceNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Device Name',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    hintText: 'e.g., MacBook Pro M1',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Device Type
                DropdownButtonFormField<String>(
                  value: widget.deviceType,
                  decoration: InputDecoration(
                    labelText: 'Device Type',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  dropdownColor: const Color(0xFF1A1F35),
                  style: const TextStyle(color: Colors.white),
                  items: deviceTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      widget.onDeviceTypeChanged(value);
                    }
                  },
                ),
                const SizedBox(height: 20),
                // Year Range Slider
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Year Range',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          widget.stillUsing
                              ? '${widget.yearRange.start.toInt()} - Present'
                              : '${widget.yearRange.start.toInt()} - ${widget.yearRange.end.toInt()}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    RangeSlider(
                      values: widget.yearRange,
                      min: 2010,
                      max: 2026,
                      divisions: 16,
                      labels: RangeLabels(
                        widget.yearRange.start.toInt().toString(),
                        widget.stillUsing
                            ? 'Present'
                            : widget.yearRange.end.toInt().toString(),
                      ),
                      activeColor: Colors.white,
                      inactiveColor: Colors.white.withOpacity(0.3),
                      onChanged: widget.stillUsing
                          ? (range) {
                              // When still using, only allow start year to change
                              widget.onYearRangeChanged(
                                RangeValues(range.start, 2026),
                              );
                            }
                          : widget.onYearRangeChanged,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Still Using Toggle
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Still Using',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Switch(
                      value: widget.stillUsing,
                      onChanged: widget.onStillUsingChanged,
                      activeColor: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Note
                TextField(
                  controller: widget.noteController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Note',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    hintText: 'Share your experience...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Send Button
                FilledButton.icon(
                  onPressed: widget.onSend,
                  icon: const Icon(Icons.send),
                  label: const Text(
                    'Send',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF02081A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}
