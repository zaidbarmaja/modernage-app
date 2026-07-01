import 'package:flutter_test/flutter_test.dart';
import 'package:mohameed_app/models/receipt.dart';
import 'package:mohameed_app/services/receipt_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ReceiptPdf.build ينتج بايتات ولا يرمي (تحميل الخطوط)', () async {
    final r = Receipt(
      id: 'abc123def',
      siteId: '',
      siteName: 'موقع تجريبي',
      ownerName: 'أبو حسن',
      amount: 1500,
      recipient: 'محمد',
      description: 'دفعة',
      date: DateTime(2024, 1, 1),
      createdByUid: '',
      createdByName: 'منفّذ',
    );
    final bytes = await ReceiptPdf.build(r);
    expect(bytes.isNotEmpty, true);
  });
}
