import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';
import 'auth_state.dart';

/// What a school can buy. Each school only sees the products it has; Rope
/// Pull offers questions from those products only. Exam practice (WAEC,
/// UTME, NECO) belongs to ACE, not Kidversity.
enum Product {
  mandarin('mandarin', 'Mandarin'),
  maths('maths', 'Mental maths'),
  labs('labs', 'Science labs');

  const Product(this.id, this.label);

  final String id;
  final String label;

  static Product? fromId(String? id) {
    for (final p in values) {
      if (p.id == id) return p;
    }
    return null;
  }

  static Set<Product> parse(Object? raw) => {
    if (raw is List)
      for (final item in raw)
        if (fromId(item?.toString()) case final Product p) p,
  };
}

/// The signed-in user's products, from `my_products()` on the server (which
/// also enforces them). Empty while loading or signed out.
final myProductsProvider = FutureProvider<Set<Product>>((ref) async {
  final signedIn = ref.watch(
    authControllerProvider.select((a) => a.isAuthenticated),
  );
  ref.watch(authControllerProvider.select((a) => a.role));
  if (!signedIn) return const {};
  final raw = await SupabaseService.instance.client.rpc('my_products');
  return Product.parse(raw);
});

/// Platform admin: every school's products, keyed by school id.
final adminSchoolProductsProvider =
    FutureProvider.autoDispose<Map<String, Set<Product>>>((ref) async {
      final rows = await SupabaseService.instance.client.rpc(
        'admin_school_products',
      );
      return {
        for (final row in (rows as List? ?? const []))
          (row as Map)['school_id'] as String: Product.parse(row['products']),
      };
    });

/// Platform admin: replace a school's products. Returns what was saved.
Future<Set<Product>> setSchoolProducts(
  String schoolId,
  Set<Product> products,
) async {
  final saved = await SupabaseService.instance.client.rpc(
    'admin_set_school_products',
    params: {
      'p_school_id': schoolId,
      'p_products': [for (final p in products) p.id],
    },
  );
  return Product.parse(saved);
}

/// True once products have loaded and [product] is among them.
final hasProductProvider = Provider.family<bool, Product>((ref, product) {
  return ref.watch(myProductsProvider).value?.contains(product) ?? false;
});
