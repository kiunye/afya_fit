// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(progressRepository)
const progressRepositoryProvider = ProgressRepositoryProvider._();

final class ProgressRepositoryProvider
    extends
        $FunctionalProvider<
          ProgressRepository,
          ProgressRepository,
          ProgressRepository
        >
    with $Provider<ProgressRepository> {
  const ProgressRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'progressRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$progressRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProgressRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProgressRepository create(Ref ref) {
    return progressRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProgressRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProgressRepository>(value),
    );
  }
}

String _$progressRepositoryHash() =>
    r'48d480159604208af6aa831a4b97f698258133c8';

@ProviderFor(progressEntries)
const progressEntriesProvider = ProgressEntriesFamily._();

final class ProgressEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Map<String, dynamic>>>,
          List<Map<String, dynamic>>,
          FutureOr<List<Map<String, dynamic>>>
        >
    with
        $FutureModifier<List<Map<String, dynamic>>>,
        $FutureProvider<List<Map<String, dynamic>>> {
  const ProgressEntriesProvider._({
    required ProgressEntriesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'progressEntriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$progressEntriesHash();

  @override
  String toString() {
    return r'progressEntriesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Map<String, dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Map<String, dynamic>>> create(Ref ref) {
    final argument = this.argument as String;
    return progressEntries(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProgressEntriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$progressEntriesHash() => r'27b1ac0cbb7a8bb24682729bef3ad1aeca3354be';

final class ProgressEntriesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<Map<String, dynamic>>>,
          String
        > {
  const ProgressEntriesFamily._()
    : super(
        retry: null,
        name: r'progressEntriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProgressEntriesProvider call(String clientId) =>
      ProgressEntriesProvider._(argument: clientId, from: this);

  @override
  String toString() => r'progressEntriesProvider';
}

@ProviderFor(progressAnalytics)
const progressAnalyticsProvider = ProgressAnalyticsFamily._();

final class ProgressAnalyticsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, dynamic>>,
          Map<String, dynamic>,
          FutureOr<Map<String, dynamic>>
        >
    with
        $FutureModifier<Map<String, dynamic>>,
        $FutureProvider<Map<String, dynamic>> {
  const ProgressAnalyticsProvider._({
    required ProgressAnalyticsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'progressAnalyticsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$progressAnalyticsHash();

  @override
  String toString() {
    return r'progressAnalyticsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<String, dynamic>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, dynamic>> create(Ref ref) {
    final argument = this.argument as String;
    return progressAnalytics(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProgressAnalyticsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$progressAnalyticsHash() => r'c952f69c564cd5b4cf307c9048bfc8090b25a804';

final class ProgressAnalyticsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Map<String, dynamic>>, String> {
  const ProgressAnalyticsFamily._()
    : super(
        retry: null,
        name: r'progressAnalyticsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProgressAnalyticsProvider call(String clientId) =>
      ProgressAnalyticsProvider._(argument: clientId, from: this);

  @override
  String toString() => r'progressAnalyticsProvider';
}
