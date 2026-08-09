String formatCurrency(int amount) {
  return amount
      .toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

double parseDouble(String value, double fallback) {
  final parsed = double.tryParse(value);
  return parsed ?? fallback;
}

int parseInt(String value, int fallback) {
  final parsed = int.tryParse(value);
  return parsed ?? fallback;
}
