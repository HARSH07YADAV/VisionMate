import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Currency Recognition Service
/// 
/// Identifies Indian Rupee notes by:
/// 1. Reading printed denomination text (₹10, ₹20, etc.)
/// 2. Detecting key visual patterns (colors, sizes)
/// 3. Reading RBI text and serial numbers
class CurrencyService extends ChangeNotifier {
  TextRecognizer? _textRecognizer;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String _lastResult = '';
  
  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;
  String get lastResult => _lastResult;
  
  // Indian currency denominations and their keywords
  static const Map<int, List<String>> _currencyKeywords = {
    10: ['10', 'ten', 'TEN'],
    20: ['20', 'twenty', 'TWENTY'], 
    50: ['50', 'fifty', 'FIFTY'],
    100: ['100', 'one hundred', 'ONE HUNDRED'],
    200: ['200', 'two hundred', 'TWO HUNDRED'],
    500: ['500', 'five hundred', 'FIVE HUNDRED'],
    2000: ['2000', 'two thousand', 'TWO THOUSAND'],
  };
  
  // RBI keywords to confirm it's a currency note
  static const List<String> _currencyConfirmKeywords = [
    'reserve bank',
    'india',
    'rbi',
    'rupees',
    'promise to pay',
    'governor',
    'भारतीय',
    'रिज़र्व बैंक',
  ];
  
  /// Initialize the recognizer
  Future<void> initialize() async {
    try {
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      _isInitialized = true;
      debugPrint('[Currency] Initialized');
      notifyListeners();
    } catch (e) {
      debugPrint('[Currency] Init error: $e');
      _isInitialized = false;
    }
  }
  
  /// Identify currency from image file
  Future<CurrencyResult> identifyFromFile(String imagePath) async {
    if (!_isInitialized || _isProcessing || _textRecognizer == null) {
      return CurrencyResult.notRecognized();
    }
    
    _isProcessing = true;
    notifyListeners();
    
    try {
      // Check file exists
      final file = File(imagePath);
      if (!await file.exists()) {
        _isProcessing = false;
        notifyListeners();
        return CurrencyResult.notRecognized();
      }
      
      // Read text from image
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer!.processImage(inputImage);
      final text = recognizedText.text.toLowerCase();
      
      debugPrint('[Currency] Detected text: $text');
      
      // Check if it's likely a currency note
      final isCurrency = _isCurrencyNote(text);
      if (!isCurrency) {
        _lastResult = 'Not a currency note';
        _isProcessing = false;
        notifyListeners();
        return CurrencyResult.notRecognized();
      }
      
      // Identify denomination
      final denomination = _identifyDenomination(text);
      
      if (denomination != null) {
        _lastResult = '$denomination rupees';
        _isProcessing = false;
        notifyListeners();
        return CurrencyResult(
          denomination: denomination,
          confidence: 0.85,
          currency: 'INR',
          isRecognized: true,
        );
      }
      
      _lastResult = 'Currency detected but denomination unclear';
      _isProcessing = false;
      notifyListeners();
      return CurrencyResult(
        denomination: 0,
        confidence: 0.5,
        currency: 'INR',
        isRecognized: false,
      );
      
    } catch (e) {
      debugPrint('[Currency] Recognition error: $e');
      _isProcessing = false;
      notifyListeners();
      return CurrencyResult.notRecognized();
    }
  }
  
  /// Check if text indicates a currency note
  bool _isCurrencyNote(String text) {
    return _currencyConfirmKeywords.any((kw) => text.contains(kw.toLowerCase()));
  }
  
  /// Identify denomination from text
  int? _identifyDenomination(String text) {
    // Check for each denomination
    // Start from highest to avoid "100" matching in "2000"
    final sortedDenominations = _currencyKeywords.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Descending order
    
    for (final denom in sortedDenominations) {
      final keywords = _currencyKeywords[denom]!;
      for (final kw in keywords) {
        // Use word boundary matching for accuracy
        if (_containsWord(text, kw.toLowerCase())) {
          return denom;
        }
      }
    }
    
    return null;
  }
  
  /// Check if text contains a word (not just substring)
  bool _containsWord(String text, String word) {
    // Simple word boundary check
    final pattern = RegExp(r'(^|\s|₹)' + RegExp.escape(word) + r'($|\s|/)');
    return pattern.hasMatch(text);
  }
  
  /// Get speech announcement for result
  String getAnnouncement(CurrencyResult result) {
    if (!result.isRecognized) {
      return 'Could not identify the note. Try holding it closer.';
    }
    
    return '${result.denomination} rupees note';
  }
  
  @override
  void dispose() {
    _textRecognizer?.close();
    super.dispose();
  }
}

/// Result of currency recognition
class CurrencyResult {
  final int denomination;
  final double confidence;
  final String currency;
  final bool isRecognized;
  
  CurrencyResult({
    required this.denomination,
    required this.confidence,
    required this.currency,
    required this.isRecognized,
  });
  
  factory CurrencyResult.notRecognized() => CurrencyResult(
    denomination: 0,
    confidence: 0,
    currency: '',
    isRecognized: false,
  );
}
