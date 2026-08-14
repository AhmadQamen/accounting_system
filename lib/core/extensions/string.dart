extension SearchFilter2 on String {
  String get searchFilter => replaceAll("أ", "ا")
      .replaceAll("ة", "ه")
      .replaceAll("إ", "ا")
      .replaceAll(" ", "")
      .toLowerCase();
  double get numValue => double.tryParse(replaceAll(",", "")) ?? 0;
}
