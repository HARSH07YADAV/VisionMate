import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// OCR Service for reading text from camera
/// 
/// Features:
/// - Read text from image file
/// - Summarize long text
/// - Detect medicine labels, signs
class OcrService extends ChangeNotifier {
  TextRecognizer? _textRecognizer;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String _lastRecognizedText = '';
  
  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;
  String get lastRecognizedText => _lastRecognizedText;
  
  /// Initialize the text recognizer
  Future<void> initialize() async {
    try {
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      _isInitialized = true;
      debugPrint('[OCR] Initialized successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('[OCR] Init error: $e');
      _isInitialized = false;
    }
  }
  
  /// Recognize text from image file
  Future<String> recognizeFromFile(String imagePath) async {
    if (!_isInitialized || _isProcessing || _textRecognizer == null) {
      return '';
    }
    
    _isProcessing = true;
    notifyListeners();
    
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer!.processImage(inputImage);
      _lastRecognizedText = recognizedText.text;
      
      _isProcessing = false;
      notifyListeners();
      
      return _lastRecognizedText;
    } catch (e) {
      debugPrint('[OCR] Recognition error: $e');
      _isProcessing = false;
      notifyListeners();
      return '';
    }
  }
  
  /// Summarize long text for TTS
  String summarizeText(String text, {int maxWords = 30}) {
    if (text.isEmpty) return 'No text found.';
    
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final words = cleaned.split(' ');
    
    if (words.length <= maxWords) {
      return cleaned;
    }
    
    return '${words.take(maxWords).join(' ')}... and more.';
  }
  
  /// Check if text looks like a medicine label
  bool isMedicineLabel(String text) {
    final lower = text.toLowerCase();
    final medicineKeywords = [
      'mg', 'ml', 'tablet', 'capsule', 'dose', 'dosage',
      'take', 'daily', 'twice', 'before', 'after', 'meals',
      'prescription', 'medicine', 'drug', 'pharmacy'
    ];
    return medicineKeywords.any((kw) => lower.contains(kw));
  }
  
  @override
  void dispose() {
    _textRecognizer?.close();
    super.dispose();
  }
}
