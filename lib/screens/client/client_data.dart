/// بيانات بوابة العملاء — منقولة من client.js.
library;

class GalleryItem {
  final String id;
  final String category;
  final String title;
  final String style;
  final String materials;
  final String area;
  const GalleryItem(
      this.id, this.category, this.title, this.style, this.materials, this.area);
}

const Map<String, String> catLabels = {
  'villas': 'فلل مودرن',
  'offices': 'تصاميم مكتبية',
  'interior': 'ديكورات داخلية',
  'gardens': 'تصميم حدائق',
};

const List<GalleryItem> gallery = [
  GalleryItem('v1', 'villas', 'فيلا مودرن بواجهة حجرية', 'حداثي بخطوط نظيفة',
      'حجر طبيعي · زجاج · ألمنيوم', '450 م²'),
  GalleryItem('v2', 'villas', 'فيلا بإطلالة بانورامية', 'معاصر فاخر',
      'خرسانة مكشوفة · زجاج عاكس', '620 م²'),
  GalleryItem('v3', 'villas', 'فيلا مينيمال أبيض', 'مينيمال',
      'بياض معماري · خشب', '380 م²'),
  GalleryItem('o1', 'offices', 'مقر إداري زجاجي', 'مكتبي حديث',
      'واجهات زجاجية · ستيل', '900 م²'),
  GalleryItem('o2', 'offices', 'مكتب مفتوح مرن', 'Open Space',
      'خشب بلوط · معدن مطفّأ', '300 م²'),
  GalleryItem('i1', 'interior', 'مجلس عربي معاصر', 'نيو-كلاسيك دافئ',
      'رخام · مخمل · نحاس', '60 م²'),
  GalleryItem('i2', 'interior', 'صالة مفتوحة على المطبخ', 'إسكندنافي',
      'خشب فاتح · حجر صناعي', '85 م²'),
  GalleryItem('i3', 'interior', 'غرفة نوم رئيسية فندقية', 'فندقي هادئ',
      'جلد · إضاءة مخفية', '40 م²'),
  GalleryItem('g1', 'gardens', 'حديقة مودرن بمسبح', 'لاندسكيب معاصر',
      'خشب WPC · عشب طبيعي', '220 م²'),
  GalleryItem('g2', 'gardens', 'جلسة خارجية مظللة', 'استرخاء خارجي',
      'بَرجولا · حجر بازلت', '120 م²'),
];

class Article {
  final String title;
  final String body;
  const Article(this.title, this.body);
}

const List<Article> articles = [
  Article('كيف تختار أرضك بذكاء؟',
      'راعِ اتجاه الشمس والرياح، وتأكد من اعتماد المخطط ومنسوب الأرض، واقرأ اشتراطات البناء للمنطقة قبل الشراء. الأرض الجيدة توفّر عليك تكاليف كبيرة لاحقًا.'),
  Article('٧ أخطاء تجنّبها عند بناء منزلك',
      'من أبرزها: البدء دون تصميم نهائي معتمد، إهمال العزل الحراري، توزيع كهرباء غير مدروس، وتجاهل التهوية الطبيعية. التخطيط المسبق يقلّل الهدر والتعديلات.'),
  Article('كيف توازن بين الجمال والتكلفة؟',
      'ركّز الميزانية على العناصر الظاهرة والمستخدمة يوميًا (الواجهة، المطبخ، الإضاءة)، واختر مواد ذكية تعطي مظهرًا فاخرًا بتكلفة معقولة. التصميم الجيد يوفّر أكثر مما يكلّف.'),
  Article('متى تبدأ بالتصميم الداخلي؟',
      'الأفضل دمج التصميم الداخلي مع المعماري من البداية، لضمان توافق الإضاءة والكهرباء والتكييف مع رؤيتك النهائية، وتفادي كسر الجدران لاحقًا.'),
];

class MapRegion {
  final String city;
  final int count;
  const MapRegion(this.city, this.count);
}

const List<MapRegion> mapRegions = [
  MapRegion('الرياض', 14),
  MapRegion('جدة', 9),
  MapRegion('الدمام', 6),
  MapRegion('مكة المكرمة', 4),
  MapRegion('القصيم', 3),
  MapRegion('أبها', 2),
];

/// ثوابت حاسبة التكاليف.
const Map<String, int> basePerM2 = {
  'villa': 1800,
  'building': 1500,
  'office': 1700,
  'rest': 1400,
  'interior': 700,
};
const Map<String, double> finishMult = {
  'economic': 1,
  'luxury': 1.55,
  'royal': 2.3,
};
const Map<String, double> regionFactor = {
  'riyadh': 1.0,
  'jeddah': 1.06,
  'dammam': 1.0,
  'makkah': 1.12,
  'other': 0.95,
};

const Map<String, String> buildTypes = {
  'villa': 'فيلا سكنية',
  'building': 'عمارة سكنية',
  'office': 'مبنى مكتبي',
  'rest': 'استراحة',
  'interior': 'تشطيب داخلي فقط',
};
const Map<String, String> regions = {
  'riyadh': 'الرياض',
  'jeddah': 'جدة',
  'dammam': 'الدمام',
  'makkah': 'مكة',
  'other': 'منطقة أخرى',
};
const Map<String, String> finishes = {
  'economic': 'اقتصادي',
  'luxury': 'فاخر',
  'royal': 'ملكي',
};

/// لون البطاقة حسب التصنيف (لتمييز المعرض دون صور).
int categoryColorValue(String cat) {
  switch (cat) {
    case 'villas':
      return 0xFF586A47;
    case 'offices':
      return 0xFF475438;
    case 'interior':
      return 0xFF8A5A3B;
    case 'gardens':
      return 0xFF6A7D55;
    default:
      return 0xFF38422C;
  }
}
