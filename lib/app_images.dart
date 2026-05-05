import 'package:flutter/material.dart';

class AppImages {
  // 1. Local Ingredients Mapping
  static String getIngredientImage(String name) {
    String lower = name.toLowerCase();

    // Make sure these filenames perfectly match what you put in the assets/images folder!
    if (lower.contains('bawang merah') || lower.contains('onion')) {
      return 'assets/images/bawang-merah.png';
    }
    if (lower.contains('bawang putih') || lower.contains('putih')) {
      return 'assets/images/bawang-putih.png';
    }
    if (lower.contains('cili') || lower.contains('chili')) {
      return 'assets/images/cili-padi.png';
    }
    if (lower.contains('ayam')) return 'assets/images/ayam.png';

    // Fallback if the image isn't found
    return 'assets/images/default-food.png';
  }

  // 2. Local Recipe Mapping
  static String getRecipeImage(String name) {
    String lower = name.toLowerCase();

    if (lower.contains('ayam goreng berempah')) return 'assets/images/ayam.JPG';
    if (lower.contains('sambal tumis cili padi')) {
      return 'assets/images/Ikan_k-1.jpg';
    }

    // Fallback recipe image
    return 'assets/images/default-food.png';
  }

  // 3. Store Logos (We can keep this as a web link since it doesn't require Firebase!)
  static ImageProvider getStoreImageProvider(String brandName) {
    String lower = brandName.toLowerCase();

    // The 3 Hardcoded Store Brands
    if (lower.contains('aeon')) {
      return const AssetImage('assets/images/aeon.png');
    }
    if (lower.contains('kk')) {
      return const AssetImage('assets/images/kkmart.png');
    }
    if (lower.contains('lotus')) {
      return const AssetImage('assets/images/lotus.png');
    }

    // The Safety Fallback (Generates an initial logo from the web if the name doesn't match)
    String encodedName = Uri.encodeComponent(brandName);
    return NetworkImage(
      'https://ui-avatars.com/api/?name=$encodedName&background=006E1C&color=fff&bold=true&size=128',
    );
  }
}
