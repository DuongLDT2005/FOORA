import 'dart:async';

/// Maps every [source] event to a new stream and forwards only the latest
/// one, cancelling the previous inner subscription (RxDart's `switchMap`).
///
/// Use it instead of `asyncExpand` when the inner stream is a Firestore
/// listener: those never complete (on web they stay open even after a
/// permission-denied error), so `asyncExpand` would wait forever and keep
/// serving the previous account after a sign-out / sign-in.
Stream<R> switchLatest<T, R>(
  Stream<T> source,
  Stream<R> Function(T value) project,
) {
  late final StreamController<R> controller;
  StreamSubscription<T>? outer;
  StreamSubscription<R>? inner;

  controller = StreamController<R>(
    onListen: () {
      outer = source.listen(
        (value) {
          final previous = inner;
          inner = null;
          previous?.cancel();
          inner = project(
            value,
          ).listen(controller.add, onError: controller.addError);
        },
        onError: controller.addError,
        onDone: () async {
          await inner?.cancel();
          await controller.close();
        },
      );
    },
    onCancel: () async {
      await inner?.cancel();
      await outer?.cancel();
    },
  );
  return controller.stream;
}
