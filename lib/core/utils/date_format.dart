String _two(int n) => n.toString().padLeft(2, '0');

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatTime(DateTime dt) {
  final local = dt.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)}';
}

String formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  return '${_months[local.month - 1]} ${local.day}, ${local.year} ${_two(local.hour)}:${_two(local.minute)}';
}
