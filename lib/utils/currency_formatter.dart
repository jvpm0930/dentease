import 'package:flutter/material.dart';

/// Utility class for formatting Philippine Peso currency
/// Provides consistent PHP currency display across the application
class CurrencyFormatter {
  // Use PHP text instead of peso symbol
  static const String pesoSymbol = 'PHP '; // Currency prefix
  static const String pesoText = 'PHP'; // Text representation

  /// Format a single price value
  /// Example: formatPeso(1500) returns "PHP 1,500"
  static String formatPeso(dynamic price) {
    if (price == null) return '$pesoSymbol 0';

    final numPrice = _parsePrice(price);
    if (numPrice == 0) return '$pesoSymbol 0';

    return '$pesoSymbol${_formatNumber(numPrice)}';
  }

  /// Format a price range
  /// Example: formatPesoRange(500, 1000) returns "PHP 500 - PHP 1,000"
  static String formatPesoRange(dynamic minPrice, dynamic maxPrice) {
    final numMin = _parsePrice(minPrice);
    final numMax = _parsePrice(maxPrice);

    if (numMin == 0 && numMax == 0) return '$pesoSymbol 0';
    if (numMax == 0 || numMax <= numMin) return formatPeso(numMin);

    return '$pesoSymbol${_formatNumber(numMin)} - $pesoSymbol${_formatNumber(numMax)}';
  }

  /// Format price with text prefix for better visibility
  /// Example: formatPesoWithText(1500) returns "PHP 1,500"
  static String formatPesoWithText(dynamic price) {
    // Since pesoSymbol is now 'PHP ', just use formatPeso
    return formatPeso(price);
  }

  /// Format price range with text prefix
  /// Example: formatPesoRangeWithText(500, 1000) returns "PHP 500 - PHP 1,000"
  static String formatPesoRangeWithText(dynamic minPrice, dynamic maxPrice) {
    // Since pesoSymbol is now 'PHP ', just use formatPesoRange
    return formatPesoRange(minPrice, maxPrice);
  }

  /// Parse price from various formats (string, number, etc.)
  static double _parsePrice(dynamic price) {
    if (price == null) return 0.0;

    if (price is num) return price.toDouble();

    if (price is String) {
      // Remove currency symbols and common prefixes
      String cleaned = price
          .replaceAll('PHP', '')
          .replaceAll('PHP', '')
          .replaceAll('P', '')
          .replaceAll(',', '')
          .trim();

      // Handle ranges - take the first number
      if (cleaned.contains('-')) {
        final parts = cleaned.split('-');
        if (parts.isNotEmpty) {
          cleaned = parts[0].trim();
        }
      }

      // Extract first number found
      final match = RegExp(r'[\d.]+').firstMatch(cleaned);
      if (match != null) {
        return double.tryParse(match.group(0)!) ?? 0.0;
      }
    }

    return 0.0;
  }

  /// Format number with thousands separator
  static String _formatNumber(double number) {
    if (number == number.toInt()) {
      // No decimal places needed
      return number.toInt().toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    } else {
      // Keep decimal places
      return number.toStringAsFixed(2).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    }
  }

  /// Create a styled peso widget for better visibility
  static Widget createPesoWidget(
    dynamic price, {
    TextStyle? style,
    bool showText = false, // Ignored - PHP prefix is always included now
    Color? color,
  }) {
    final formattedPrice = formatPeso(price);

    return Text(
      formattedPrice,
      style: (style ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }

  /// Create a styled peso range widget
  static Widget createPesoRangeWidget(
    dynamic minPrice,
    dynamic maxPrice, {
    TextStyle? style,
    bool showText = false, // Ignored - PHP prefix is always included now
    Color? color,
  }) {
    final formattedRange = formatPesoRange(minPrice, maxPrice);

    return Text(
      formattedRange,
      style: (style ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }
}
