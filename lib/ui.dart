import 'package:flutter/material.dart';

const royal = Color(0xFF1F4E79),
    gold = Color(0xFFD4AF37),
    cream = Color(0xFFFFF9E5),
    mist = Color(0xFFF8F9FA),
    coral = Color(0xFFE77474),
    green = Color(0xFF45A881);
TextStyle serif(double size, [Color color = royal]) => TextStyle(
  fontFamily: 'Playfair',
  fontSize: size,
  fontWeight: FontWeight.w700,
  color: color,
);
TextStyle eyebrow([Color color = Colors.grey]) => TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.5,
  color: color,
);
Widget dot(Color color) => Container(
  width: 5,
  height: 5,
  margin: const EdgeInsets.symmetric(horizontal: 2),
  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
);
Widget iconBox(IconData icon, Color color) => Container(
  padding: const EdgeInsets.all(11),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .09),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Icon(icon, size: 23, color: color),
);

class Panel extends StatelessWidget {
  final Widget child;
  final Color color;
  final bool goldBorder;
  const Panel({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.goldBorder = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: gold.withValues(alpha: goldBorder ? 1 : .2),
        width: goldBorder ? 2 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: royal.withValues(alpha: .035),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
bool sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;
double parseNumber(String s) => double.parse(s.replaceAll(',', '.'));
DateTime parseDate(String s) {
  final p = s.split('/').map(int.parse).toList();
  return DateTime(p[2], p[1], p[0]);
}

String dateLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
const monthsFr = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];
const monthsEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const taskCategories = [
  'Cuisine',
  'Salon',
  'Chambre',
  'Salle de bain',
  'Jardin',
  'Vêtements',
  'Autres',
];
const categoryEnglish = {
  'Cuisine': 'Kitchen',
  'Salon': 'Living room',
  'Chambre': 'Bedroom',
  'Salle de bain': 'Bathroom',
  'Jardin': 'Garden',
  'Vêtements': 'Clothes',
  'Autres': 'Other',
  'Loyer': 'Rent',
  'Courses': 'Groceries',
  'Abos': 'Subscriptions',
  'Essence': 'Fuel',
  'Loisirs': 'Leisure',
  'Autre': 'Other',
};

class HouseTask {
  String name, english, category, owner;
  DateTime date;
  bool done, recurring;
  HouseTask(
    this.name,
    this.english,
    this.category,
    this.owner,
    this.date, {
    this.done = false,
    this.recurring = false,
  });
  String label(bool french) => french ? name : english;
}

class Expense {
  final String name, english, category, owner;
  final double amount;
  final DateTime date;
  final bool recurring;
  Expense(
    this.name,
    this.english,
    this.category,
    this.amount,
    this.owner,
    this.date, {
    this.recurring = false,
  });
  String label(bool french) => french ? name : english;
}

class ShoppingItem {
  String name, english, unit;
  double quantity, price;
  bool checked;
  ShoppingItem(
    this.name,
    this.english,
    this.quantity,
    this.price,
    this.unit, {
    this.checked = false,
  });
  String label(bool french) => french ? name : english;
}

class ShoppingListData {
  final String name;
  final List<ShoppingItem> items;
  ShoppingListData(this.name, this.items);
  double get total => items.fold(0, (sum, i) => sum + i.quantity * i.price);
}

class CoupleEvent {
  final String name, english;
  final DateTime date;
  CoupleEvent(this.name, this.english, this.date);
  String label(bool french) => french ? name : english;
}

class Debt {
  final String name, owner;
  final double amount;
  bool settled = false;
  Debt(this.name, this.amount, this.owner);
}

class FieldSpec {
  final String key, label;
  final String? initial;
  final List<String>? options;
  final bool number, positive, toggle, date;
  FieldSpec(
    this.key,
    this.label, {
    this.initial,
    this.options,
    this.number = false,
    this.positive = false,
    this.toggle = false,
    this.date = false,
  });
}

class EntrySheet extends StatefulWidget {
  final String title, saveLabel, cancelLabel;
  final List<FieldSpec> fields;
  const EntrySheet({
    super.key,
    required this.title,
    required this.fields,
    required this.saveLabel,
    required this.cancelLabel,
  });
  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  final formKey = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  final values = <String, String>{};
  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      values[f.key] =
          f.initial ?? f.options?.first ?? (f.toggle ? 'false' : '');
      controllers[f.key] = TextEditingController(text: values[f.key]);
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: .3),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(widget.title, style: serif(25)),
            const SizedBox(height: 24),
            for (final f in widget.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: f.toggle
                    ? SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          f.label,
                          style: const TextStyle(fontSize: 14),
                        ),
                        activeThumbColor: gold,
                        value: values[f.key] == 'true',
                        onChanged: (v) => setState(() => values[f.key] = '$v'),
                      )
                    : f.options != null
                    ? DropdownButtonFormField<String>(
                        initialValue: values[f.key],
                        isExpanded: true,
                        decoration: InputDecoration(labelText: f.label),
                        items: f.options!
                            .map(
                              (o) => DropdownMenuItem(
                                value: o,
                                child: Text(
                                  widget.saveLabel == 'Save'
                                      ? categoryEnglish[o] ?? o
                                      : o,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => values[f.key] = v!,
                      )
                    : TextFormField(
                        controller: controllers[f.key],
                        readOnly: f.date,
                        keyboardType: f.number
                            ? const TextInputType.numberWithOptions(
                                decimal: true,
                              )
                            : TextInputType.text,
                        decoration: InputDecoration(
                          labelText: f.label,
                          suffixIcon: f.date
                              ? const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                )
                              : null,
                        ),
                        onTap: f.date
                            ? () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: parseDate(
                                    controllers[f.key]!.text,
                                  ),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (d != null) {
                                  controllers[f.key]!.text = dateLabel(d);
                                }
                              }
                            : null,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return f.label;
                          }
                          if (f.number) {
                            final n = double.tryParse(v.replaceAll(',', '.'));
                            if (n == null ||
                                !n.isFinite ||
                                n < 0 ||
                                (f.positive && n <= 0)) {
                              return widget.saveLabel == 'Save'
                                  ? 'Enter a valid amount'
                                  : 'Entrez un montant valide';
                            }
                          }
                          return null;
                        },
                      ),
              ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  for (final f in widget.fields) {
                    if (!f.toggle && f.options == null) {
                      values[f.key] = controllers[f.key]!.text.trim();
                    }
                  }
                  Navigator.pop(context, values);
                }
              },
              child: Text(widget.saveLabel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(widget.cancelLabel),
            ),
          ],
        ),
      ),
    ),
  );
}
