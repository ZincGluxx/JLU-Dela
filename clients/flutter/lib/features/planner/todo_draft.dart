import '../../core/models/todo.dart';

const String todoDraftScope = 'todo';
const String todoNewDraftKey = 'new';

String todoDraftKeyFor(Todo? todo) => todo?.id ?? todoNewDraftKey;
