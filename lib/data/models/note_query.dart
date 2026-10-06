import 'package:freezed_annotation/freezed_annotation.dart';

part 'note_query.freezed.dart';

/// How students can sort notes.
enum NoteSort { newest, popular, priceLow, priceHigh }

/// Free / paid filter.
enum PriceFilter { any, free, paid }

/// What a student is looking at: where in the catalog + filters + sort.
///
/// Firestore can only range-filter on the field it sorts by, so a price
/// range (min/max) or "paid only" makes the results sort by price.
@freezed
abstract class NoteQuery with _$NoteQuery {
  const factory NoteQuery({
    String? universityId,
    String? semesterId,
    String? subjectId,
    String? moduleId,
    @Default(NoteSort.newest) NoteSort sort,
    @Default(PriceFilter.any) PriceFilter priceFilter,

    /// Price range in paise (inclusive). Null = no limit.
    int? minPrice,
    int? maxPrice,
  }) = _NoteQuery;

  const NoteQuery._();

  bool get hasPriceRange =>
      minPrice != null || maxPrice != null || priceFilter == PriceFilter.paid;

  /// The sort actually applied (price wins when a price range is set).
  NoteSort get effectiveSort =>
      !hasPriceRange || priceFilter == PriceFilter.free
      ? sort
      : (sort == NoteSort.priceHigh ? NoteSort.priceHigh : NoteSort.priceLow);
}
