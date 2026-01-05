// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutrition_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(nutritionRepository)
const nutritionRepositoryProvider = NutritionRepositoryProvider._();

final class NutritionRepositoryProvider
    extends
        $FunctionalProvider<
          NutritionRepository,
          NutritionRepository,
          NutritionRepository
        >
    with $Provider<NutritionRepository> {
  const NutritionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nutritionRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nutritionRepositoryHash();

  @$internal
  @override
  $ProviderElement<NutritionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NutritionRepository create(Ref ref) {
    return nutritionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NutritionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NutritionRepository>(value),
    );
  }
}

String _$nutritionRepositoryHash() =>
    r'884a75635292eb982ac75b7a8140046c41596c82';

@ProviderFor(nutritionPlans)
const nutritionPlansProvider = NutritionPlansProvider._();

final class NutritionPlansProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Map<String, dynamic>>>,
          List<Map<String, dynamic>>,
          FutureOr<List<Map<String, dynamic>>>
        >
    with
        $FutureModifier<List<Map<String, dynamic>>>,
        $FutureProvider<List<Map<String, dynamic>>> {
  const NutritionPlansProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nutritionPlansProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nutritionPlansHash();

  @$internal
  @override
  $FutureProviderElement<List<Map<String, dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Map<String, dynamic>>> create(Ref ref) {
    return nutritionPlans(ref);
  }
}

String _$nutritionPlansHash() => r'63be883a671a32c81d1f42b19662b49f03364458';

@ProviderFor(nutritionPlan)
const nutritionPlanProvider = NutritionPlanFamily._();

final class NutritionPlanProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, dynamic>>,
          Map<String, dynamic>,
          FutureOr<Map<String, dynamic>>
        >
    with
        $FutureModifier<Map<String, dynamic>>,
        $FutureProvider<Map<String, dynamic>> {
  const NutritionPlanProvider._({
    required NutritionPlanFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'nutritionPlanProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$nutritionPlanHash();

  @override
  String toString() {
    return r'nutritionPlanProvider'
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
    return nutritionPlan(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NutritionPlanProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$nutritionPlanHash() => r'5e971b10a512ccad73210859e4621254bc0455e1';

final class NutritionPlanFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Map<String, dynamic>>, String> {
  const NutritionPlanFamily._()
    : super(
        retry: null,
        name: r'nutritionPlanProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NutritionPlanProvider call(String id) =>
      NutritionPlanProvider._(argument: id, from: this);

  @override
  String toString() => r'nutritionPlanProvider';
}
