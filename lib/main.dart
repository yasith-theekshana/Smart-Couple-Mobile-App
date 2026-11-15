import 'features/invitations/presentation/invitation_link_listener.dart';
import 'features/couple/presentation/screens/couple_space_header.dart';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/domain/app_user.dart';
import 'features/auth/presentation/screens/auth_gate.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

import 'firebase_options.dart';

import 'ui.dart';
import 'articles.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    const ProviderScope(child: InvitationLinkListener(child: SmartCoupleApp())),
  );
}

class SmartCoupleApp extends StatelessWidget {
  final Widget? home;
  const SmartCoupleApp({super.key, this.home});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Smart Couple',
    initialRoute: '/',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: royal,
        primary: royal,
        secondary: gold,
      ),
      textTheme: const TextTheme(bodyMedium: TextStyle(color: royal)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: mist,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ),
    home:
        home ??
        AuthGate(
          dashboardBuilder: (user) =>
              CoupleHome(key: ValueKey(user.uid), user: user),
        ),
  );
}

class CoupleHome extends StatefulWidget {
  final AppUser? user;
  const CoupleHome({super.key, this.user});
  @override
  State<CoupleHome> createState() => _CoupleHomeState();
}

class _CoupleHomeState extends State<CoupleHome> {
  bool french = true;
  int page = 0, financeTab = 0, taskTab = 0;
  String? taskCategory;
  double florian = 3000, sophie = 2800;
  DateTime month = DateTime(2026, 4),
      selectedDay = DateTime(2026, 4, 6),
      financeMonth = DateTime(2026, 4);
  final tasks = <HouseTask>[
    HouseTask(
      'Préparer le petit-déjeuner',
      'Prepare breakfast',
      'Cuisine',
      'Florian',
      DateTime(2026, 4, 6),
      recurring: true,
    ),
    HouseTask(
      'Préparer le dîner',
      'Prepare dinner',
      'Cuisine',
      'Sophie',
      DateTime(2026, 4, 6),
      recurring: true,
    ),
    HouseTask(
      'Lessive',
      'Laundry',
      'Vêtements',
      'Florian',
      DateTime(2026, 4, 7),
      done: true,
    ),
    HouseTask(
      'Repasser les vêtements',
      'Iron clothes',
      'Vêtements',
      'Sophie',
      DateTime(2026, 4, 8),
      done: true,
    ),
    HouseTask(
      'Tondre la pelouse',
      'Mow the lawn',
      'Jardin',
      'Florian',
      DateTime(2026, 4, 11),
    ),
    HouseTask(
      'Nettoyer la salle de bain',
      'Clean the bathroom',
      'Salle de bain',
      'Sophie',
      DateTime(2026, 4, 11),
      recurring: true,
    ),
    HouseTask(
      'Faire les courses',
      'Go shopping',
      'Autres',
      'Florian & Sophie',
      DateTime(2026, 4, 11),
      recurring: true,
    ),
  ];
  final expenses = <Expense>[
    Expense(
      'Loyer Avril',
      'April rent',
      'Loyer',
      1250,
      'Florian',
      DateTime(2026, 4, 1),
      recurring: true,
    ),
    Expense(
      'Courses Bio',
      'Organic groceries',
      'Courses',
      84.50,
      'Sophie',
      DateTime(2026, 4, 5),
    ),
    Expense(
      'Netflix',
      'Netflix',
      'Abos',
      17.99,
      'Florian',
      DateTime(2026, 4, 10),
      recurring: true,
    ),
    Expense(
      'Plein Essence',
      'Fuel',
      'Essence',
      75,
      'Florian',
      DateTime(2026, 4, 12),
    ),
  ];
  final lists = <ShoppingListData>[
    ShoppingListData('Liste Principale', [
      ShoppingItem('Pain', 'Bread', 2, 1.20, 'u'),
      ShoppingItem('Lait', 'Milk', 1, .95, 'L', checked: true),
      ShoppingItem('Lessive', 'Detergent', 1, 12.50, 'u'),
      ShoppingItem('Pommes', 'Apples', 1.5, 2.40, 'kg'),
    ]),
    ShoppingListData('Semaine du 18/05/2026', [
      ShoppingItem('Lait demi-écrémé', 'Milk', 2, 1.25, 'L'),
      ShoppingItem('Pain de campagne', 'Bread', 1, 1.80, 'u'),
    ]),
  ];
  int activeList = 0;
  final events = <CoupleEvent>[
    CoupleEvent('Dîner en amoureux', 'Date night', DateTime(2026, 4, 6)),
  ];
  final debts = <Debt>[];
  String tr(String fr, String en) => french ? fr : en;
  String money(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', french ? ',' : '.')} €';
  String category(String v) => french ? v : categoryEnglish[v] ?? v;
  String monthLabel(DateTime d) =>
      '${(french ? monthsFr : monthsEn)[d.month - 1]} ${d.year}';
  List<Expense> get monthExpenses => expenses
      .where(
        (e) =>
            sameMonth(e.date, financeMonth) ||
            (e.recurring &&
                !DateTime(e.date.year, e.date.month).isAfter(financeMonth)),
      )
      .toList();
  double get spent => monthExpenses.fold(0, (s, e) => s + e.amount);
  double get budget => florian + sophie;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(
              key: ValueKey(page),
              child: [home, finances, shopping, calendar, household][page](),
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: DecoratedBox(
      decoration: BoxDecoration(
        color: cream,
        border: Border(top: BorderSide(color: gold.withValues(alpha: .18))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: List.generate(
              5,
              (i) => Expanded(
                child: Semantics(
                  selected: page == i,
                  child: InkWell(
                    key: ValueKey('nav-$i'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() {
                      page = i;
                      financeTab = 0;
                      taskTab = 0;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: page == i
                                  ? royal.withValues(alpha: .08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              [
                                Icons.home_rounded,
                                Icons.account_balance_wallet_rounded,
                                Icons.shopping_cart_rounded,
                                Icons.calendar_month_rounded,
                                Icons.cleaning_services_rounded,
                              ][i],
                              color: page == i ? royal : gold,
                              size: 23,
                            ),
                          ),
                          Text(
                            [
                              tr('Accueil', 'Home'),
                              tr('Finances', 'Finance'),
                              'Shopping',
                              'Agenda',
                              tr('Ménages', 'Tasks'),
                            ][i],
                            style: TextStyle(
                              fontSize: 9,
                              color: page == i ? royal : gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget scroll(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
    children: children,
  );
  Widget heading(String title, {Widget? action}) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Row(
      children: [
        IconButton(
          onPressed: () => setState(() => page = 0),
          icon: const Icon(Icons.chevron_left, color: royal),
          tooltip: tr('Accueil', 'Home'),
        ),
        Expanded(child: Text(title, style: serif(26))),
        ?action,
      ],
    ),
  );
  Widget section(String label, {Widget? action}) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 16),
    child: Row(
      children: [
        Expanded(child: Text(label.toUpperCase(), style: eyebrow())),
        ?action,
      ],
    ),
  );
  Widget action(
    String label,
    VoidCallback onTap, {
    IconData icon = Icons.add,
  }) => FilledButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
  Widget tabs(List<String> labels, int current, ValueChanged<int> onTap) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          children: List.generate(
            labels.length,
            (i) => Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 2,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == current ? gold : gold.withValues(alpha: .2),
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: i == current ? gold : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
  Widget home() => scroll([
    Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('BIENVENUE', 'WELCOME'), style: eyebrow(gold)),
              const SizedBox(height: 4),
              Text(widget.user?.name ?? 'Florian & Sophie', style: serif(23)),
            ],
          ),
        ),
        InkWell(
          key: const ValueKey('profile'),
          onTap: profile,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: gold, width: 2),
            ),
            child: const CircleAvatar(
              radius: 23,
              backgroundImage: AssetImage('assets/images/couple.jpg'),
            ),
          ),
        ),
      ],
    ),
    if (widget.user?.coupleId case final id?) CoupleSpaceHeader(coupleId: id),
    const SizedBox(height: 32),
    section(
      tr('Répartition des responsabilités', 'Responsibility distribution'),
    ),
    Row(
      children: [
        Expanded(
          child: tile(
            tr('Finances', 'Finances'),
            Icons.account_balance_wallet_rounded,
            1,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: tile(
            tr('Ménages', 'Tasks'),
            Icons.cleaning_services_rounded,
            4,
          ),
        ),
      ],
    ),
    const SizedBox(height: 28),
    section(tr('Supplémentaires', 'Additional items')),
    Row(
      children: [
        Expanded(child: tile('Shopping', Icons.shopping_cart_rounded, 2)),
        const SizedBox(width: 12),
        Expanded(
          child: tile(
            tr('Calendrier', 'Calendar'),
            Icons.calendar_month_rounded,
            3,
          ),
        ),
      ],
    ),
    const SizedBox(height: 28),
    section(
      'Articles',
      action: TextButton(
        onPressed: () => openArticles(context, french),
        child: Text(tr('VOIR TOUT', 'VIEW ALL'), style: eyebrow(gold)),
      ),
    ),
    ArticleCard(index: 0, french: french),
  ]);
  Widget tile(String title, IconData icon, int destination) => InkWell(
    onTap: () => setState(() => page = destination),
    borderRadius: BorderRadius.circular(18),
    child: Panel(
      goldBorder: true,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: royal.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: royal),
          ),
          const SizedBox(height: 14),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
        ],
      ),
    ),
  );
  Widget finances() => scroll([
    heading('Finances'),
    tabs(
      [
        'Dashboard',
        tr('Dépenses', 'Expenses'),
        tr('Dettes', 'Debts'),
        tr('Analyse', 'Analysis'),
      ],
      financeTab,
      (i) => setState(() => financeTab = i),
    ),
    monthPicker(financeMonth, (d) => setState(() => financeMonth = d)),
    const SizedBox(height: 18),
    if (financeTab == 0) ...[
      Panel(
        color: royal,
        child: Column(
          children: [
            Text(tr('RESTE TOTAL', 'REMAINING BUDGET'), style: eyebrow(gold)),
            const SizedBox(height: 12),
            Text(money(budget - spent), style: serif(34, Colors.white)),
            const SizedBox(height: 12),
            Text(
              '${tr('Budget conjoint', 'Shared budget')} · ${money(budget)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: stat(
              tr('Dépensé', 'Spent'),
              money(spent),
              Icons.north_east,
              coral,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: stat(
              tr('Reste', 'Remaining'),
              money(budget - spent),
              Icons.savings_outlined,
              green,
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      section(tr('Contributions du couple', 'Partner contributions')),
      partner('Florian', florian),
      const SizedBox(height: 12),
      partner('Sophie', sophie),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: editBudget,
        icon: const Icon(Icons.edit_outlined, size: 16),
        label: Text(tr('Modifier le budget conjoint', 'Edit shared budget')),
      ),
      const SizedBox(height: 16),
      action(tr('Nouvelle dépense', 'New expense'), expenseForm),
    ],
    if (financeTab == 1) ...[
      action(tr('Nouvelle dépense', 'New expense'), expenseForm),
      const SizedBox(height: 20),
      if (monthExpenses.isEmpty)
        empty(tr('Aucune dépense ce mois-ci', 'No expenses this month')),
      ...monthExpenses.map(
        (e) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            child: Row(
              children: [
                iconBox(Icons.receipt_long_outlined, coral),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.label(french),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${category(e.category)} · ${e.owner}\n${dateLabel(e.date)}${e.recurring ? ' · ↻' : ''}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  money(e.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                IconButton(
                  tooltip: tr('Supprimer dépense', 'Delete expense'),
                  onPressed: () => setState(() => expenses.remove(e)),
                  icon: const Icon(Icons.close, size: 17),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
    if (financeTab == 2) ...[
      Panel(
        color: cream,
        child: Text(
          tr(
            'Pour un partage plus juste, suivez les montants à rembourser entre vous.',
            'For a fairer split, track the amounts you owe each other.',
          ),
          style: const TextStyle(height: 1.6, fontSize: 12),
        ),
      ),
      const SizedBox(height: 18),
      action(tr('Déclarer une dette', 'Add debt'), debtForm),
      const SizedBox(height: 20),
      if (debts.isEmpty)
        empty(tr('Tout est équilibré', 'All settled'), icon: Icons.balance),
      ...debts.map(
        (d) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${d.owner} → ${d.owner == 'Florian' ? 'Sophie' : 'Florian'}',
                  style: serif(19),
                ),
                const SizedBox(height: 8),
                Text(
                  money(d.amount),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(d.name),
                TextButton(
                  onPressed: () => setState(() => d.settled = !d.settled),
                  child: Text(
                    d.settled
                        ? tr('Réglé ✓', 'Settled ✓')
                        : tr('Marquer comme réglé', 'Settle debt'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
    if (financeTab == 3) ...[
      section(tr('Répartition des dépenses', 'Spending breakdown')),
      Panel(
        child: Column(
          children: [
            for (final cat in monthExpenses.map((e) => e.category).toSet()) ...[
              Row(
                children: [
                  Expanded(child: Text(category(cat))),
                  Text(
                    money(
                      monthExpenses
                          .where((e) => e.category == cat)
                          .fold(0, (s, e) => s + e.amount),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: spent == 0
                      ? 0
                      : monthExpenses
                                .where((e) => e.category == cat)
                                .fold(0.0, (s, e) => s + e.amount) /
                            spent,
                  color: gold,
                  backgroundColor: mist,
                ),
              ),
              const SizedBox(height: 22),
            ],
            if (monthExpenses.isEmpty) empty(tr('Aucune donnée', 'No data')),
          ],
        ),
      ),
      const SizedBox(height: 20),
      partner('Florian', florian),
      const SizedBox(height: 12),
      partner('Sophie', sophie),
    ],
  ]);
  Widget stat(String title, String value, IconData icon, Color color) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 14),
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 6),
        FittedBox(
          child: Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
  Widget partner(String name, double contribution) {
    final paid = monthExpenses
        .where((e) => e.owner == name)
        .fold(0.0, (s, e) => s + e.amount);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              iconBox(Icons.person_outline, name == 'Florian' ? royal : gold),
              const SizedBox(width: 12),
              Expanded(child: Text(name, style: serif(20))),
              Text(
                money(contribution),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: contribution <= 0 ? 0 : (paid / contribution).clamp(0, 1),
              minHeight: 6,
              color: name == 'Florian' ? royal : gold,
              backgroundColor: mist,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${tr('Dépensé', 'Spent')} ${money(paid)}  ·  ${tr('Reste', 'Remaining')} ${money(contribution - paid)}',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget shopping() {
    final list = lists[activeList];
    return scroll([
      heading(
        'Shopping',
        action: IconButton(
          tooltip: tr('Historique', 'History'),
          onPressed: shoppingHistory,
          icon: const Icon(Icons.history, color: gold),
        ),
      ),
      Text(
        activeList == 0
            ? tr('LISTE PRINCIPALE', 'MAIN SHOPPING LIST')
            : list.name.toUpperCase(),
        style: eyebrow(gold),
      ),
      const SizedBox(height: 18),
      Panel(
        color: royal,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('TOTAL ESTIMÉ', 'ESTIMATED TOTAL'),
                    style: eyebrow(gold),
                  ),
                  const SizedBox(height: 8),
                  Text(money(list.total), style: serif(28, Colors.white)),
                ],
              ),
            ),
            Column(
              children: [
                const Icon(Icons.shopping_basket_outlined, color: gold),
                const SizedBox(height: 8),
                Text(
                  '${list.items.where((i) => i.checked).length}/${list.items.length} ${tr('articles', 'items')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: newShoppingList,
              icon: const Icon(Icons.add, size: 16),
              label: Text(tr('Créer liste', 'Create list')),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: tr('Vider la liste', 'Empty list'),
            onPressed: () async {
              if (await confirm(tr('Vider la liste ?', 'Empty list?'))) {
                setState(() => list.items.clear());
              }
            },
            icon: const Icon(Icons.delete_outline, color: coral),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (list.items.isEmpty)
        empty(
          tr('Votre panier est vide', 'Your cart is empty'),
          icon: Icons.shopping_basket_outlined,
        ),
      ...list.items.map(
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            child: Row(
              children: [
                Checkbox(
                  value: i.checked,
                  activeColor: gold,
                  onChanged: (v) => setState(() => i.checked = v!),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => shoppingForm(item: i),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i.label(french),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            decoration: i.checked
                                ? TextDecoration.lineThrough
                                : null,
                            color: i.checked ? Colors.grey : royal,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${i.quantity} ${i.unit} × ${money(i.price)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  money(i.quantity * i.price),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                IconButton(
                  tooltip: tr('Supprimer article', 'Delete item'),
                  onPressed: () => setState(() => list.items.remove(i)),
                  icon: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      action(tr('Ajouter au panier', 'Add to cart'), () => shoppingForm()),
    ]);
  }

  Widget household() {
    final visible = tasks
        .where(
          (t) =>
              (taskTab == 0 || (taskTab == 1 ? !t.done : t.done)) &&
              (taskCategory == null || taskCategory == t.category),
        )
        .toList();
    return scroll([
      heading(tr('Ménages', 'Household tasks')),
      tabs(
        [
          tr('Tableau', 'Dashboard'),
          tr('À faire', 'To do'),
          tr('Terminé', 'Completed'),
        ],
        taskTab,
        (i) => setState(() => taskTab = i),
      ),
      Row(
        children: [
          Expanded(
            child: Text(
              tr('Un quotidien mieux partagé', 'A better everyday, together'),
              style: serif(21),
            ),
          ),
          iconBox(Icons.cleaning_services_outlined, gold),
        ],
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ChoiceChip(
            label: Text(tr('Tout', 'All')),
            selected: taskCategory == null,
            onSelected: (_) => setState(() => taskCategory = null),
          ),
          for (final c in taskCategories)
            ChoiceChip(
              label: Text(category(c)),
              selected: taskCategory == c,
              onSelected: (v) => setState(() => taskCategory = v ? c : null),
            ),
        ],
      ),
      const SizedBox(height: 18),
      action(tr('Ajouter une tâche', 'Add task'), () => taskForm()),
      const SizedBox(height: 22),
      if (visible.isEmpty)
        empty(tr('Aucune tâche prévue', 'No tasks scheduled')),
      ...visible.map(
        (t) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            child: Row(
              children: [
                Checkbox(
                  value: t.done,
                  activeColor: gold,
                  onChanged: (v) => setState(() => t.done = v!),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => taskForm(task: t),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.label(french),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            decoration: t.done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${category(t.category)} · ${t.owner}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${dateLabel(t.date)}${t.recurring ? ' · ↻' : ''}',
                          style: const TextStyle(fontSize: 10, color: gold),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: tr('Supprimer tâche', 'Delete task'),
                  onPressed: () => setState(() => tasks.remove(t)),
                  icon: const Icon(Icons.close, size: 17),
                ),
              ],
            ),
          ),
        ),
      ),
    ]);
  }

  Widget monthPicker(DateTime value, ValueChanged<DateTime> change) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      IconButton(
        tooltip: tr('Mois précédent', 'Previous month'),
        onPressed: () => change(DateTime(value.year, value.month - 1)),
        icon: const Icon(Icons.chevron_left, color: gold),
      ),
      Text(monthLabel(value), style: serif(20)),
      IconButton(
        tooltip: tr('Mois suivant', 'Next month'),
        onPressed: () => change(DateTime(value.year, value.month + 1)),
        icon: const Icon(Icons.chevron_right, color: gold),
      ),
    ],
  );
  Widget calendar() {
    final offset = DateTime(month.year, month.month).weekday - 1;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final dayTasks = tasks.where(
      (t) =>
          sameDay(t.date, selectedDay) ||
          (t.recurring &&
              !selectedDay.isBefore(t.date) &&
              selectedDay.weekday == t.date.weekday),
    );
    final dayExpenses = expenses.where(
      (e) =>
          sameDay(e.date, selectedDay) ||
          (e.recurring &&
              !selectedDay.isBefore(e.date) &&
              e.date.day == selectedDay.day),
    );
    final dayEvents = events.where((e) => sameDay(e.date, selectedDay));
    return scroll([
      heading(tr('Calendrier', 'Calendar')),
      monthPicker(month, (d) => setState(() => month = d)),
      const SizedBox(height: 18),
      Row(
        children:
            (french
                    ? ['L', 'M', 'M', 'J', 'V', 'S', 'D']
                    : ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                .map(
                  (d) => Expanded(
                    child: Center(child: Text(d, style: eyebrow(gold))),
                  ),
                )
                .toList(),
      ),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: ((offset + count) / 7).ceil() * 7,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: .85,
        ),
        itemBuilder: (context, i) {
          final day = i - offset + 1;
          if (day < 1 || day > count) {
            return const SizedBox();
          }
          final date = DateTime(month.year, month.month, day),
              selected = sameDay(date, selectedDay);
          final hasTask = tasks.any(
            (t) =>
                sameDay(t.date, date) ||
                (t.recurring &&
                    !date.isBefore(t.date) &&
                    date.weekday == t.date.weekday),
          );
          final hasExpense = expenses.any(
            (e) =>
                sameDay(e.date, date) ||
                (e.recurring && !date.isBefore(e.date) && e.date.day == day),
          );
          final hasEvent = events.any((e) => sameDay(e.date, date));
          return InkWell(
            key: ValueKey('day-$day'),
            onTap: () => setState(() => selectedDay = date),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: selected ? royal : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      color: selected ? Colors.white : royal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasExpense) dot(gold),
                      if (hasTask) dot(green),
                      if (hasEvent) dot(coral),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 20),
      Wrap(
        alignment: WrapAlignment.center,
        runSpacing: 8,
        children: [
          dot(gold),
          Text(
            tr(' Finances   ', ' Finance   '),
            style: const TextStyle(fontSize: 10),
          ),
          dot(green),
          Text(
            tr(' Ménages   ', ' Tasks   '),
            style: const TextStyle(fontSize: 10),
          ),
          dot(coral),
          Text(
            tr(' Événements', ' Events'),
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
      const SizedBox(height: 28),
      section(dateLabel(selectedDay)),
      if (dayTasks.isEmpty && dayExpenses.isEmpty && dayEvents.isEmpty)
        empty(tr('Aucun événement prévu', 'No scheduled activities')),
      ...dayTasks.map(
        (t) => agendaRow(
          t.label(french),
          t.owner,
          green,
          Icons.cleaning_services_outlined,
        ),
      ),
      ...dayExpenses.map(
        (e) => agendaRow(
          e.label(french),
          money(e.amount),
          gold,
          Icons.account_balance_wallet_outlined,
        ),
      ),
      ...dayEvents.map(
        (e) => agendaRow(
          e.label(french),
          tr('À deux', 'Together'),
          coral,
          Icons.favorite_outline,
          onDelete: () => setState(() => events.remove(e)),
        ),
      ),
      const SizedBox(height: 18),
      action(tr('Nouvel événement', 'New event'), eventForm),
    ]);
  }

  Widget agendaRow(
    String title,
    String subtitle,
    Color color,
    IconData icon, {
    VoidCallback? onDelete,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Panel(
      child: Row(
        children: [
          iconBox(icon, color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: tr('Supprimer événement', 'Delete event'),
              onPressed: onDelete,
              icon: const Icon(Icons.close, size: 16),
            ),
        ],
      ),
    ),
  );
  Widget empty(String message, {IconData icon = Icons.check_circle_outline}) =>
      Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(icon, size: 36, color: gold),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
  Future<bool> confirm(String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title, style: serif(22)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Annuler', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('Supprimer', 'Delete')),
            ),
          ],
        ),
      ) ??
      false;
  Future<Map<String, String>?> form(String title, List<FieldSpec> fields) =>
      showModalBottomSheet<Map<String, String>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        builder: (ctx) => EntrySheet(
          title: title,
          fields: fields,
          saveLabel: tr('Enregistrer', 'Save'),
          cancelLabel: tr('Annuler', 'Cancel'),
        ),
      );
  Future<void> editBudget() async {
    final r = await form(tr('Budget conjoint', 'Shared budget'), [
      FieldSpec('florian', 'Florian (€)', initial: '$florian', number: true),
      FieldSpec('sophie', 'Sophie (€)', initial: '$sophie', number: true),
    ]);
    if (r != null && mounted) {
      setState(() {
        florian = parseNumber(r['florian']!);
        sophie = parseNumber(r['sophie']!);
      });
    }
  }

  Future<void> expenseForm() async {
    final r = await form(tr('Nouvelle dépense', 'New expense'), [
      FieldSpec('name', tr('Description', 'Description')),
      FieldSpec(
        'amount',
        tr('Montant (€)', 'Amount (€)'),
        number: true,
        positive: true,
      ),
      FieldSpec(
        'category',
        tr('Catégorie', 'Category'),
        options: ['Loyer', 'Courses', 'Abos', 'Essence', 'Loisirs', 'Autre'],
      ),
      FieldSpec(
        'owner',
        tr('Qui paye ?', 'Who paid?'),
        options: ['Florian', 'Sophie'],
      ),
      FieldSpec(
        'date',
        'Date',
        initial: dateLabel(DateTime(financeMonth.year, financeMonth.month, 1)),
        date: true,
      ),
      FieldSpec(
        'recurring',
        tr('Paiement récurrent', 'Recurring payment'),
        toggle: true,
      ),
    ]);
    if (r != null && mounted) {
      setState(
        () => expenses.add(
          Expense(
            r['name']!,
            r['name']!,
            r['category']!,
            parseNumber(r['amount']!),
            r['owner']!,
            parseDate(r['date']!),
            recurring: r['recurring'] == 'true',
          ),
        ),
      );
    }
  }

  Future<void> shoppingForm({ShoppingItem? item}) async {
    final r = await form(
      item == null
          ? tr('Ajouter au panier', 'Add to cart')
          : tr('Modifier article', 'Edit item'),
      [
        FieldSpec('name', tr('Article', 'Item'), initial: item?.label(french)),
        FieldSpec(
          'quantity',
          tr('Quantité', 'Quantity'),
          initial: '${item?.quantity ?? 1}',
          number: true,
          positive: true,
        ),
        FieldSpec(
          'unit',
          tr('Unité', 'Unit'),
          initial: item?.unit,
          options: ['u', 'kg', 'g', 'L', 'ml', 'paq'],
        ),
        FieldSpec(
          'price',
          tr('Prix unitaire (€)', 'Unit price (€)'),
          initial: '${item?.price ?? 0}',
          number: true,
        ),
      ],
    );
    if (r != null && mounted) {
      setState(() {
        if (item != null) {
          item.name = r['name']!;
          item.english = r['name']!;
          item.quantity = parseNumber(r['quantity']!);
          item.unit = r['unit']!;
          item.price = parseNumber(r['price']!);
        } else {
          lists[activeList].items.add(
            ShoppingItem(
              r['name']!,
              r['name']!,
              parseNumber(r['quantity']!),
              parseNumber(r['price']!),
              r['unit']!,
            ),
          );
        }
      });
    }
  }

  Future<void> newShoppingList() async {
    final r = await form(tr('Créer une liste', 'Create a list'), [
      FieldSpec('name', tr('Nom de la liste', 'List name')),
    ]);
    if (r != null && mounted) {
      setState(() {
        lists.add(ShoppingListData(r['name']!, []));
        activeList = lists.length - 1;
      });
    }
  }

  void shoppingHistory() => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (ctx) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(24),
      children: [
        Text(tr('Mes listes', 'My lists'), style: serif(25)),
        const SizedBox(height: 16),
        for (int i = 0; i < lists.length; i++)
          ListTile(
            leading: const Icon(Icons.shopping_basket_outlined, color: gold),
            title: Text(
              i == 0
                  ? tr('Liste Principale', 'Main Shopping List')
                  : lists[i].name,
            ),
            subtitle: Text(
              '${lists[i].items.length} ${tr('articles', 'items')} · ${money(lists[i].total)}',
            ),
            trailing: i == activeList
                ? const Icon(Icons.check, color: gold)
                : const Icon(Icons.chevron_right),
            onTap: () {
              setState(() => activeList = i);
              Navigator.pop(ctx);
            },
          ),
      ],
    ),
  );
  Future<void> taskForm({HouseTask? task}) async {
    final r = await form(
      task == null
          ? tr('Ajouter une tâche', 'Add task')
          : tr('Modifier la tâche', 'Edit task'),
      [
        FieldSpec(
          'name',
          tr('Nom de la tâche', 'Task name'),
          initial: task?.label(french),
        ),
        FieldSpec(
          'category',
          tr('Catégorie', 'Category'),
          initial: task?.category,
          options: taskCategories,
        ),
        FieldSpec(
          'owner',
          tr('Assigné à', 'Assigned to'),
          initial: task?.owner,
          options: ['Florian', 'Sophie', 'Florian & Sophie'],
        ),
        FieldSpec(
          'date',
          tr('Date d’échéance', 'Due date'),
          initial: dateLabel(task?.date ?? selectedDay),
          date: true,
        ),
        FieldSpec(
          'recurring',
          tr('Tâche récurrente', 'Recurring task'),
          initial: '${task?.recurring ?? false}',
          toggle: true,
        ),
      ],
    );
    if (r != null && mounted) {
      setState(() {
        if (task != null) {
          task.name = r['name']!;
          task.english = r['name']!;
          task.category = r['category']!;
          task.owner = r['owner']!;
          task.date = parseDate(r['date']!);
          task.recurring = r['recurring'] == 'true';
        } else {
          tasks.add(
            HouseTask(
              r['name']!,
              r['name']!,
              r['category']!,
              r['owner']!,
              parseDate(r['date']!),
              recurring: r['recurring'] == 'true',
            ),
          );
        }
      });
    }
  }

  Future<void> debtForm() async {
    final r = await form(tr('Déclarer une dette', 'Add debt'), [
      FieldSpec('name', tr('Description', 'Description')),
      FieldSpec(
        'amount',
        tr('Montant (€)', 'Amount (€)'),
        number: true,
        positive: true,
      ),
      FieldSpec(
        'owner',
        tr('Qui doit rembourser ?', 'Who owes?'),
        options: ['Florian', 'Sophie'],
      ),
    ]);
    if (r != null && mounted) {
      setState(
        () =>
            debts.add(Debt(r['name']!, parseNumber(r['amount']!), r['owner']!)),
      );
    }
  }

  Future<void> eventForm() async {
    final r = await form(tr('Nouvel événement', 'New event'), [
      FieldSpec('name', tr('Titre de l’événement', 'Event title')),
      FieldSpec('date', 'Date', initial: dateLabel(selectedDay), date: true),
    ]);
    if (r != null && mounted) {
      setState(
        () => events.add(
          CoupleEvent(r['name']!, r['name']!, parseDate(r['date']!)),
        ),
      );
    }
  }

  void profile() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', width: 60, height: 60),
            const SizedBox(height: 14),
            Text(widget.user?.name ?? 'Florian & Sophie', style: serif(25)),
            const SizedBox(height: 8),
            Text('SMART COUPLE', style: eyebrow(gold)),
            const SizedBox(height: 26),
            if (widget.user != null) Text(widget.user!.email),
            if (widget.user != null)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ProviderScope.containerOf(
                    context,
                    listen: false,
                  ).read(authControllerProvider.notifier).signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            Text('LANGUE / LANGUAGE', style: eyebrow()),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Français')),
                ButtonSegment(value: false, label: Text('English')),
              ],
              selected: {french},
              onSelectionChanged: (v) {
                setState(() => french = v.first);
                update(() {});
              },
            ),
            const SizedBox(height: 24),
            Text(
              tr(
                'Votre espace partagé, un quotidien plus serein.',
                'Your shared space for a calmer everyday.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('Fermer', 'Close')),
            ),
          ],
        ),
      ),
    ),
  );
}
