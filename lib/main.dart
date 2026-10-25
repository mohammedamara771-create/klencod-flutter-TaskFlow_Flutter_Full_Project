import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bg = Color(0xFF090B18);
const panel = Color(0xFF171A2E);
const purple = Color(0xFF7655F6);
const muted = Color(0xFFADB2CC);
const green = Color(0xFF00D6A0);

void main() => runApp(const TaskFlowApp());

class TaskItem {
  String title;
  String category;
  String priority;
  bool done;
  TaskItem({required this.title, this.category = 'شخصي', this.priority = 'متوسطة', this.done = false});
  Map<String, dynamic> toJson() => {'title': title, 'category': category, 'priority': priority, 'done': done};
  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
    title: j['title'] as String? ?? '', category: j['category'] as String? ?? 'شخصي',
    priority: j['priority'] as String? ?? 'متوسطة', done: j['done'] as bool? ?? false,
  );
}

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TaskFlow', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark, scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: purple, brightness: Brightness.dark)),
    home: const Directionality(textDirection: TextDirection.rtl, child: HomePage()),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<TaskItem> tasks = [];
  final search = TextEditingController();
  bool loading = true;
  int page = 0;
  String filter = 'الكل';

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('taskflow_tasks');
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        tasks.addAll(list.map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e as Map))));
      }
    } catch (e) { debugPrint('Load tasks failed: $e'); }
    if (mounted) setState(() => loading = false);
  }
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('taskflow_tasks', jsonEncode(tasks.map((e) => e.toJson()).toList()));
  }
  int get completed => tasks.where((t) => t.done).length;
  int get active => tasks.length - completed;
  List<TaskItem> get shown => tasks.where((t) {
    final q = search.text.trim().toLowerCase();
    final searchOk = t.title.toLowerCase().contains(q);
    final filterOk = filter == 'الكل' || (filter == 'قيد التنفيذ' && !t.done) || (filter == 'المكتملة' && t.done);
    return searchOk && filterOk;
  }).toList();

  Future<void> _editTask({TaskItem? task}) async {
    final title = TextEditingController(text: task?.title ?? '');
    String category = task?.category ?? 'شخصي';
    String priority = task?.priority ?? 'متوسطة';
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      backgroundColor: panel, title: Text(task == null ? 'مهمة جديدة' : 'تعديل المهمة'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'اسم المهمة', border: OutlineInputBorder(), prefixIcon: Icon(Icons.edit_note))),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(value: category, decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder()),
          items: ['شخصي','دراسة','عمل','صحة','منزل'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setDialog(() => category = v ?? category)),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(value: priority, decoration: const InputDecoration(labelText: 'الأولوية', border: OutlineInputBorder()),
          items: ['منخفضة','متوسطة','عالية'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setDialog(() => priority = v ?? priority)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () { if (title.text.trim().isNotEmpty) Navigator.pop(ctx, true); }, child: const Text('حفظ'))],
    )));
    if (ok == true && mounted) {
      setState(() {
        if (task == null) { tasks.insert(0, TaskItem(title: title.text.trim(), category: category, priority: priority)); }
        else { task.title = title.text.trim(); task.category = category; task.priority = priority; }
      });
      await _save();
    }
    title.dispose();
  }
  Future<void> _toggle(TaskItem task) async { setState(() => task.done = !task.done); await _save(); }
  Future<void> _delete(TaskItem task) async { setState(() => tasks.remove(task)); await _save(); }
  Future<void> _clearAll() async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('حذف جميع المهام؟'),
      content: const Text('لا يمكن التراجع عن هذا الإجراء.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف الكل'))]));
    if (yes == true) { setState(tasks.clear); await _save(); }
  }
  @override
  void dispose() { search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: loading ? const Center(child: CircularProgressIndicator()) : IndexedStack(index: page, children: [
      _home(), _home(), _stats(), _settings(),
    ])),
    floatingActionButton: page < 2 ? FloatingActionButton(backgroundColor: purple, onPressed: () => _editTask(), child: const Icon(Icons.add, color: Colors.white)) : null,
    bottomNavigationBar: NavigationBar(backgroundColor: const Color(0xFF101326), selectedIndex: page,
      onDestinationSelected: (i) => setState(() => page = i), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'المهام'),
        NavigationDestination(icon: Icon(Icons.query_stats_outlined), selectedIcon: Icon(Icons.query_stats), label: 'الإحصائيات'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
      ]),
  );

  Widget _home() => ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 90), children: [
    Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: purple, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.done_all, color: Colors.white)),
      const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('TaskFlow', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)), Text('نظّم يومك بذكاء', style: TextStyle(color: muted))]))]),
    const SizedBox(height: 24),
    Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF4825B8), Color(0xFF171A42)]), borderRadius: BorderRadius.circular(22)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('مرحباً بك!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('خطوة صغيرة اليوم، إنجاز كبير غداً.', style: TextStyle(color: Color(0xFFDCD6FF)))])),
    const SizedBox(height: 18), Row(children: [Expanded(child: _stat('كل المهام', '${tasks.length}', Icons.assignment_outlined, const Color(0xFF8290FF))), const SizedBox(width: 8),
      Expanded(child: _stat('قيد التنفيذ', '$active', Icons.schedule, const Color(0xFFFFB52E))), const SizedBox(width: 8), Expanded(child: _stat('المكتملة', '$completed', Icons.check_circle_outline, green))]),
    const SizedBox(height: 20), TextField(controller: search, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: 'ابحث عن مهمة...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: panel, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
    const SizedBox(height: 12), Wrap(spacing: 8, children: ['الكل','قيد التنفيذ','المكتملة'].map((v) => ChoiceChip(label: Text(v), selected: filter == v, selectedColor: purple, onSelected: (_) => setState(() => filter = v)).toList()),
    const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('مهامي', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)), Text('${shown.length} مهام', style: const TextStyle(color: muted))]),
    const SizedBox(height: 12),
    if (shown.isEmpty) Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18)), child: const Column(children: [Icon(Icons.inbox_outlined, size: 42, color: muted), SizedBox(height: 10), Text('لا توجد مهام هنا', style: TextStyle(color: muted)), SizedBox(height: 5), Text('اضغط على + لإضافة مهمة جديدة', style: TextStyle(color: muted, fontSize: 12))]))
    else ...shown.map(_taskCard),
  ]);

  Widget _stat(String title, String value, IconData icon, Color color) => Container(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 3), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withAlpha(75))),
    child: Column(children: [Icon(icon, color: color), const SizedBox(height: 7), Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)), Text(title, style: const TextStyle(color: muted, fontSize: 10))]));
  Widget _tag(String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withAlpha(35), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withAlpha(100))), child: Text(label, style: TextStyle(color: color, fontSize: 11)));
  Widget _taskCard(TaskItem task) {
    final c = task.priority == 'عالية' ? const Color(0xFFFF426D) : task.priority == 'متوسطة' ? const Color(0xFFFFB52E) : green;
    return Container(margin: const EdgeInsets.only(bottom: 11), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFF2A3155))),
      child: Row(children: [IconButton(onPressed: () => _toggle(task), icon: Icon(task.done ? Icons.check_circle : Icons.circle_outlined, color: task.done ? green : muted)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(task.title, style: TextStyle(fontWeight: FontWeight.bold, decoration: task.done ? TextDecoration.lineThrough : null, color: task.done ? muted : Colors.white)), const SizedBox(height: 8), Wrap(spacing: 5, children: [_tag(task.category, const Color(0xFF9B88FF)), _tag(task.priority, c)])])),
        PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _editTask(task: task); if (v == 'delete') _delete(task); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'delete', child: Text('حذف'))])]));
  }
  Widget _stats() {
    final p = tasks.isEmpty ? 0.0 : completed / tasks.length;
    return ListView(padding: const EdgeInsets.all(20), children: [const Text('الإحصائيات', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('تابع تقدمك وإنجازاتك', style: TextStyle(color: muted)), const SizedBox(height: 22),
      _stat('إجمالي المهام', '${tasks.length}', Icons.assignment_outlined, const Color(0xFF8290FF)), const SizedBox(height: 12), _stat('المهام المكتملة', '$completed', Icons.check_circle_outline, green), const SizedBox(height: 12), _stat('المهام المتبقية', '$active', Icons.schedule, const Color(0xFFFFB52E)), const SizedBox(height: 22),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('نسبة الإنجاز', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)), const SizedBox(height: 18), LinearProgressIndicator(value: p, minHeight: 10, borderRadius: BorderRadius.circular(10), color: green, backgroundColor: const Color(0xFF2A3155)), const SizedBox(height: 12), Text('${(p * 100).round()}% من مهامك مكتملة', style: const TextStyle(color: muted))]))]);
  }
  Widget _settings() => ListView(padding: const EdgeInsets.all(20), children: [const Text('الإعدادات', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), const SizedBox(height: 20),
    const ListTile(leading: CircleAvatar(backgroundColor: purple, child: Icon(Icons.person_outline)), title: Text('مستخدم TaskFlow'), subtitle: Text('نظّم يومك بذكاء')),
    const ListTile(leading: Icon(Icons.palette_outlined, color: purple), title: Text('المظهر'), subtitle: Text('الوضع الداكن')),
    const ListTile(leading: Icon(Icons.storage_outlined, color: green), title: Text('حفظ البيانات'), subtitle: Text('تُحفظ المهام على هذا الجهاز')),
    ListTile(leading: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFFF426D)), title: const Text('حذف جميع المهام'), onTap: _clearAll), const SizedBox(height: 25), const Center(child: Text('TaskFlow • الإصدار 1.0.0', style: TextStyle(color: muted)))]);
}