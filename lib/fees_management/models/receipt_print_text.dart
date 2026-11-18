/// Verify URL for a receipt code, used by the printed QR and the footer.
/// Built from the running origin so dev, staging and production links all
/// point back at the same deployment that printed them.
String verifyUrlFor(String code) {
  final u = Uri.base;
  return '${u.origin}${u.path}?c=$code';
}

/// Amount in words (Indian system: crore, lakh, thousand, hundred).
/// `45230` → `Rupees Forty-Five Thousand Two Hundred Thirty Only`.
String amountInWords(double amount) {
  final n = amount.round();
  if (n <= 0) return 'Rupees Zero Only';
  if (n >= 10000000) return 'Rupees ${_twoDigits(n ~/ 10000000)} Crore'
      '${_subHundred(n % 10000000)} Only';
  return 'Rupees${_subHundred(n)} Only';
}

String _subHundred(int n) {
  var out = '';
  if (n >= 100000) {
    out += ' ${_twoDigits(n ~/ 100000)} Lakh';
    n %= 100000;
  }
  if (n >= 1000) {
    out += ' ${_twoDigits(n ~/ 1000)} Thousand';
    n %= 1000;
  }
  if (n >= 100) {
    out += ' ${_ones(n ~/ 100)} Hundred';
    n %= 100;
  }
  if (n > 0) out += ' ${_twoDigits(n)}';
  return out;
}

const _oneToNineteen = [
  '',
  'One',
  'Two',
  'Three',
  'Four',
  'Five',
  'Six',
  'Seven',
  'Eight',
  'Nine',
  'Ten',
  'Eleven',
  'Twelve',
  'Thirteen',
  'Fourteen',
  'Fifteen',
  'Sixteen',
  'Seventeen',
  'Eighteen',
  'Nineteen',
];

const _tens = [
  '',
  '',
  'Twenty',
  'Thirty',
  'Forty',
  'Fifty',
  'Sixty',
  'Seventy',
  'Eighty',
  'Ninety',
];

String _ones(int n) => _oneToNineteen[n];

String _twoDigits(int n) {
  if (n < 20) return _oneToNineteen[n];
  final t = _tens[n ~/ 10];
  final o = n % 10;
  return o == 0 ? t : '$t-${_oneToNineteen[o]}';
}
