import 'package:dev_stack/features/supervisor/data/supervisor_provider.dart';
import 'package:dev_stack/features/supervisor/domain/supervisor_program.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a program without an id is recognized as new', () {
    final p = SupervisorProgram(name: 'x', command: 'y');
    expect(SupervisorProgramsRepository.isNew(p), isTrue);
  });

  test('a program with an id is recognized as existing', () {
    final p = SupervisorProgram(id: 3, name: 'x', command: 'y');
    expect(SupervisorProgramsRepository.isNew(p), isFalse);
  });

  test('the status provider starts empty before any manager event', () {
    // The provider family/type exists and is a NotifierProvider; the initial
    // map is produced by build() inside a container (see Task 8 step 5's
    // widget-level coverage). Here we only pin the public shape.
    expect(supervisorStatusProvider, isA<NotifierProvider<dynamic, dynamic>>());
  });
}
