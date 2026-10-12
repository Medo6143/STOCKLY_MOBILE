/// The input fields of the product, unit, adjustment and count forms.
enum ProductField {
  name,
  barcode,
  category,
  baseUnitName,
  costPrice,
  baseUnitSellPrice,
  lowStockThreshold,
  openingQuantity,
  unitName,
  unitFactor,
  unitSellPrice,
  unitBarcode,
  quantityChange,
  countedQuantity,
  stockUnit,
  note,
}

/// Why a field was rejected before anything was sent. The number issues
/// reuse the messages of the matching server codes (design §5.3).
enum ProductFieldIssue {
  required,
  tooLong,
  invalidNumber,
  tooManyDecimals,
  negative,
  notPositive,
  zero,
  outOfRange,
}
