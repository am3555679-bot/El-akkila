import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ElAkkilaApp());
}

class ElAkkilaApp extends StatelessWidget {
  const ElAkkilaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'El Akkila',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const RestaurantListScreen(),
    );
  }
}

class RestaurantListScreen extends StatelessWidget {
  const RestaurantListScreen({super.key});

  static const String secretPin = '3865299';

  void _verifyPinAndExecute(BuildContext context, VoidCallback onSuccess) {
    final TextEditingController pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('أدخل الـ PIN السري'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (pinController.text == secretPin) {
                Navigator.pop(ctx);
                onSuccess();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الـ PIN غير صحيح!')),
                );
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  void _addOrEditRestaurant(BuildContext context, {DocumentSnapshot? doc}) {
    final nameController = TextEditingController(text: doc != null ? doc['name'] : '');
    final phoneController = TextEditingController(text: doc != null ? doc['phone'] : '');
    final menuController = TextEditingController(text: doc != null ? doc['menu'] : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          top: 16, left: 16, right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(doc == null ? 'إضافة مطعم جديد' : 'تعديل المطعم', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم المطعم')),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
            TextField(controller: menuController, maxLines: 3, decoration: const InputDecoration(labelText: 'المنيو / قائمة الطعام')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (doc == null) {
                  await FirebaseFirestore.instance.collection('restaurants').add({
                    'name': nameController.text,
                    'phone': phoneController.text,
                    'menu': menuController.text,
                    'ratingCount': 0,
                    'totalRating': 0.0,
                  });
                } else {
                  await doc.reference.update({
                    'name': nameController.text,
                    'phone': phoneController.text,
                    'menu': menuController.text,
                  });
                }
                if (context.mounted) Navigator.pop(ctx);
              },
              child: Text(doc == null ? 'إضافة' : 'حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  void _addRating(BuildContext context, DocumentSnapshot doc) {
    double selectedRating = 5.0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تقييم ${doc['name']}'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('التقييم: ${selectedRating.toStringAsFixed(1)} ★'),
              Slider(
                value: selectedRating,
                min: 1, max: 5, divisions: 4,
                onChanged: (val) => setState(() => selectedRating = val),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final data = doc.data() as Map<String, dynamic>?;
              int currentCount = data != null && data.containsKey('ratingCount') ? data['ratingCount'] : 0;
              double currentTotal = data != null && data.containsKey('totalRating') ? (data['totalRating'] as num).toDouble() : 0.0;
              
              await doc.reference.update({
                'ratingCount': currentCount + 1,
                'totalRating': currentTotal + selectedRating,
              });
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('إرسال التقييم'),
          ),
        ],
      ),
    );
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri url = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('El Akkila - الأكيلة')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _verifyPinAndExecute(context, () => _addOrEditRestaurant(context)),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              int count = data.containsKey('ratingCount') ? data['ratingCount'] : 0;
              double total = data.containsKey('totalRating') ? (data['totalRating'] as num).toDouble() : 0.0;
              double avgRating = count == 0 ? 0.0 : total / count;

              return Card(
                margin: const EdgeInsets.all(8),
                child: ExpansionTile(
                  title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('★ ${avgRating.toStringAsFixed(1)} ($count تقييم)'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.phone, color: Colors.green),
                        onPressed: () => _makeCall(data['phone'] ?? ''),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _verifyPinAndExecute(context, () => _addOrEditRestaurant(context, doc: doc)),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('المنيو:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(data['menu'] ?? ''),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () => _addRating(context, doc),
                            icon: const Icon(Icons.star),
                            label: const Text('أضف تقييمك (بدون PIN)'),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ElAkkilaApp());
}

class ElAkkilaApp extends StatelessWidget {
  const ElAkkilaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'El Akkila',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const RestaurantListScreen(),
    );
  }
}

class RestaurantListScreen extends StatelessWidget {
  const RestaurantListScreen({super.key});

  static const String secretPin = '3865299';

  void _verifyPinAndExecute(BuildContext context, VoidCallback onSuccess) {
    final TextEditingController pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('أدخل الـ PIN السري'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (pinController.text == secretPin) {
                Navigator.pop(ctx);
                onSuccess();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الـ PIN غير صحيح!')),
                );
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  void _addOrEditRestaurant(BuildContext context, {DocumentSnapshot? doc}) {
    final nameController = TextEditingController(text: doc != null ? doc['name'] : '');
    final phoneController = TextEditingController(text: doc != null ? doc['phone'] : '');
    final menuController = TextEditingController(text: doc != null ? doc['menu'] : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          top: 16, left: 16, right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(doc == null ? 'إضافة مطعم جديد' : 'تعديل المطعم', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم المطعم')),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
            TextField(controller: menuController, maxLines: 3, decoration: const InputDecoration(labelText: 'المنيو / قائمة الطعام')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (doc == null) {
                  await FirebaseFirestore.instance.collection('restaurants').add({
                    'name': nameController.text,
                    'phone': phoneController.text,
                    'menu': menuController.text,
                    'ratingCount': 0,
                    'totalRating': 0.0,
                  });
                } else {
                  await doc.reference.update({
                    'name': nameController.text,
                    'phone': phoneController.text,
                    'menu': menuController.text,
                  });
                }
                if (context.mounted) Navigator.pop(ctx);
              },
              child: Text(doc == null ? 'إضافة' : 'حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  void _addRating(BuildContext context, DocumentSnapshot doc) {
    double selectedRating = 5.0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تقييم ${doc['name']}'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('التقييم: ${selectedRating.toStringAsFixed(1)} ★'),
              Slider(
                value: selectedRating,
                min: 1, max: 5, divisions: 4,
                onChanged: (val) => setState(() => selectedRating = val),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final data = doc.data() as Map<String, dynamic>?;
              int currentCount = data != null && data.containsKey('ratingCount') ? data['ratingCount'] : 0;
              double currentTotal = data != null && data.containsKey('totalRating') ? (data['totalRating'] as num).toDouble() : 0.0;
              
              await doc.reference.update({
                'ratingCount': currentCount + 1,
                'totalRating': currentTotal + selectedRating,
              });
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('إرسال التقييم'),
          ),
        ],
      ),
    );
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri url = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('El Akkila - الأكيلة')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _verifyPinAndExecute(context, () => _addOrEditRestaurant(context)),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              int count = data.containsKey('ratingCount') ? data['ratingCount'] : 0;
              double total = data.containsKey('totalRating') ? (data['totalRating'] as num).toDouble() : 0.0;
              double avgRating = count == 0 ? 0.0 : total / count;

              return Card(
                margin: const EdgeInsets.all(8),
                child: ExpansionTile(
                  title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('★ ${avgRating.toStringAsFixed(1)} ($count تقييم)'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.phone, color: Colors.green),
                        onPressed: () => _makeCall(data['phone'] ?? ''),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _verifyPinAndExecute(context, () => _addOrEditRestaurant(context, doc: doc)),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('المنيو:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(data['menu'] ?? ''),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () => _addRating(context, doc),
                            icon: const Icon(Icons.star),
                            label: const Text('أضف تقييمك (بدون PIN)'),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ElAkkilaApp());
}

class ElAkkilaApp extends StatelessWidget {
  const ElAkkilaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'El Akkila',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const RestaurantListScreen(),
    );
  }
}

class RestaurantListScreen extends StatelessWidget {
  const RestaurantListScreen({super.key});

  static const String secretPin = '3865299';

  void _verifyPinAndExecute(BuildContext context, VoidCallback onSuccess) {
    final TextEditingController pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('أدخل الـ PIN السري'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (pinController.text == secretPin) {
                Navigator.pop(ctx);
                onSuccess();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الـ PIN غير صحيح!')),
                );
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  void _addOrEditRestaurant(BuildContext context, {DocumentSnapshot? doc}) {
    final nameController = TextEditingController(text: doc != null ? doc['name'] : '');
    final phoneController = TextEditingController(text: doc != null ? doc['phone'] : '');
    final menuController = TextEditingController(text: doc != null ? doc['menu'] : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          top: 16, left: 16, right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(doc == null ? 'إضافة مطعم جديد' : 'تعديل المطعم', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم المطعم')),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
            TextField(controller: menuController, maxLines: 3, decoration: const InputDecoration(labelText: 'المنيو / قائمة الطعام')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (doc == null) {
                  await FirebaseFirestore.instance.collection('restaurants').add({
                    'name': nameController.text,
                    'phone': phoneController.text,
                    'menu': menuController.text,
                    'ratingCount': 0,
                    'totalRating': 0.0,
                  });
                } else {
                  await doc.reference.update({
                    'name': nameController.text,
                    'phone': phoneController.text,
                    'menu': menuController.text,
                  });
                }
                if (context.mounted) Navigator.pop(ctx);
              },
              child: Text(doc == null ? 'إضافة' : 'حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  void _addRating(BuildContext context, DocumentSnapshot doc) {
    double selectedRating = 5.0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تقييم ${doc['name']}'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('التقييم: ${selectedRating.toStringAsFixed(1)} ★'),
              Slider(
                value: selectedRating,
                min: 1, max: 5, divisions: 4,
                onChanged: (val) => setState(() => selectedRating = val),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final data = doc.data() as Map<String, dynamic>?;
              int currentCount = data != null && data.containsKey('ratingCount') ? data['ratingCount'] : 0;
              double currentTotal = data != null && data.containsKey('totalRating') ? (data['totalRating'] as num).toDouble() : 0.0;
              
              await doc.reference.update({
                'ratingCount': currentCount + 1,
                'totalRating': currentTotal + selectedRating,
              });
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('إرسال التقييم'),
          ),
        ],
      ),
    );
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri url = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('El Akkila - الأكيلة')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _verifyPinAndExecute(context, () => _addOrEditRestaurant(context)),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              int count = data.containsKey('ratingCount') ? data['ratingCount'] : 0;
              double total = data.containsKey('totalRating') ? (data['totalRating'] as num).toDouble() : 0.0;
              double avgRating = count == 0 ? 0.0 : total / count;

              return Card(
                margin: const EdgeInsets.all(8),
                child: ExpansionTile(
                  title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('★ ${avgRating.toStringAsFixed(1)} ($count تقييم)'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.phone, color: Colors.green),
                        onPressed: () => _makeCall(data['phone'] ?? ''),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _verifyPinAndExecute(context, () => _addOrEditRestaurant(context, doc: doc)),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('المنيو:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(data['menu'] ?? ''),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () => _addRating(context, doc),
                            icon: const Icon(Icons.star),
                            label: const Text('أضف تقييمك (بدون PIN)'),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ElAkkilaApp());
}

class ElAkkilaApp extends StatelessWidget {
  const ElAkkilaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'El Akkila',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.orange),
      home: const RestaurantListScreen(),
    );
  }
}

class RestaurantListScreen extends StatelessWidget {
  const RestaurantListScreen({super.key});

  static const String secretPin = '3865299';

  void _verifyPinAndExecute(BuildContext context, VoidCallback onSuccess) {
    final TextEditingController pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('أدخل الـ PIN السري'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (pinController.text == secretPin) {
                Navigator.pop(ctx);
                onSuccess();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الـ PIN غير صحيح!')),
                );
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  void _addOrEditRestaurant(BuildContext context, {DocumentSnapshot? doc}) {
    final nameController = TextEditingController(text: doc != null ? doc['name'] : '');
    final phoneController = TextEditingController(text: doc != null ? doc['phone'] : '');
    final menuController = TextEditingController(text: doc != null ? doc['menu'] : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          top: 16, left: 16, right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(doc == null ? 'إضافة مطعم جديد' : 'تعديل المطعم', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم المطعم')),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
            TextField(controller: menuController, maxLines: 3, decoration: const InputDecoration(labelText: 'المنيو / قائمة الطعام')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (doc == null) {
                  await FirebaseFirestore.instance.collection('restaurants').add({
                    'name': nameController.text,
                    'phone': phoneController.text,
                    'menu': menuController.text,
                    'ratingCount': 0,
                    'totalRating': 0.0,
                  });
                } else {
                  await doc.reference.update({
                    'name': nameController.text,
                    'phone': phoneController.text,
                    'menu': menuController.text,
                  });
                }
                if (context.mounted) Navigator.pop(ctx);
              },
              child: Text(doc == null ? 'إضافة' : 'حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  void _addRating(BuildContext context, DocumentSnapshot doc) {
    double selectedRating = 5.0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تقييم ${doc['name']}'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('التقييم: ${selectedRating.toStringAsFixed(1)} ★'),
              Slider(
                value: selectedRating,
                min: 1, max: 5, divisions: 4,
                onChanged: (val) => setState(() => selectedRating = val),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final data = doc.data() as Map<String, dynamic>?;
              int currentCount = data != null && data.containsKey('ratingCount') ? data['ratingCount'] : 0;
              double currentTotal = data != null && data.containsKey('totalRating') ? (data['totalRating'] as num).toDouble() : 0.0;
              
              await doc.reference.update({
                'ratingCount': currentCount + 1,
                'totalRating': currentTotal + selectedRating,
              });
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('إرسال التقييم'),
          ),
        ],
      ),
    );
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri url = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('El Akkila - الأكيلة')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _verifyPinAndExecute(context, () => _addOrEditRestaurant(context)),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              int count = data.containsKey('ratingCount') ? data['ratingCount'] : 0;
              double total = data.containsKey('totalRating') ? (data['totalRating'] as num).toDouble() : 0.0;
              double avgRating = count == 0 ? 0.0 : total / count;

              return Card(
                margin: const EdgeInsets.all(8),
                child: ExpansionTile(
                  title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('★ ${avgRating.toStringAsFixed(1)} ($count تقييم)'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.phone, color: Colors.green),
                        onPressed: () => _makeCall(data['phone'] ?? ''),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _verifyPinAndExecute(context, () => _addOrEditRestaurant(context, doc: doc)),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('المنيو:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(data['menu'] ?? ''),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () => _addRating(context, doc),
                            icon: const Icon(Icons.star),
                            label: const Text('أضف تقييمك (بدون PIN)'),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}