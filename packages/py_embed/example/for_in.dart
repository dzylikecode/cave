class IntRange with Iterable<int> {
  final int start;
  final int end;

  IntRange(this.start, this.end);

  @override
  Iterator<int> get iterator =>
      Iterable<int>.generate(
        end - start,
        (index) => start + index,
      ).iterator;

  @override
  int get length => end - start;
}

void main() {
  final range = IntRange(3, 7);

  for (final value in range) {
    print(value);
  }

  range.map((value) => value * 2).forEach(print);

  print(range.length);

}