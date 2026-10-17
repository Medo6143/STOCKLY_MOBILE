/// The parts of a product that fly from its list row to its detail.
enum ProductHeroPart { badge, name }

/// The hero tag of [part] of the product [productId] (design-refresh
/// brief: hero animation for the name and badge).
(ProductHeroPart, String) productHeroTag(
  ProductHeroPart part,
  String productId,
) => (part, productId);
