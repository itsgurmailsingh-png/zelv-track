import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

const _kShopColors = [
  Color(0xFF00BFFF), Color(0xFF7C6EFF), Color(0xFF00C48C),
  Color(0xFFFFB800), Color(0xFFFF6B35), Color(0xFF5C6EFF),
  Color(0xFFFF4B6E), Color(0xFF00D4A0),
];

Color _shopColor(int index) => _kShopColors[index % _kShopColors.length];

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});
  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final _s = StorageService.instance;
  List<ShoppingItem> _items = [];
  List<ShopModel>    _shops = [];

  @override
  void initState() { super.initState(); _load(); }

  void _load() => setState(() {
    _items = _s.getShoppingList();
    _shops = _s.getShops();
  });

  Future<void> _toggle(String id) async {
    HapticFeedback.selectionClick();
    await _s.toggleShoppingItem(id);
    _load();
  }

  Future<void> _delete(String id) async {
    await _s.deleteShoppingItem(id);
    _load();
  }

  void _openItemSheet([ShoppingItem? editing, String? preselectedShopId]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemSheet(
        editing: editing,
        preselectedShopId: preselectedShopId,
        shops: _shops,
        onSave: (item) async {
          if (editing == null) {
            await _s.addShoppingItem(item);
          } else {
            final list = _s.getShoppingList()
                .map((i) => i.id == item.id ? item : i).toList();
            await _s.saveShoppingList(list);
          }
          _load();
        },
        onDelete: editing == null ? null : () async {
          await _s.deleteShoppingItem(editing.id);
          _load();
        },
        onAddShop: (shop) async {
          await _s.addShop(shop);
          _load();
        },
      ),
    );
  }

  void _openManageShops() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManageShopsSheet(
        shops: _shops,
        onAdd: (shop) async { await _s.addShop(shop); _load(); },
        onDelete: (id) async { await _s.deleteShop(id); _load(); },
      ),
    );
  }

  List<ShoppingItem> get _done => _items.where((i) => i.done).toList();
  List<ShoppingItem> _itemsForShop(String? shopId) =>
      _items.where((i) => !i.done && i.shop == shopId).toList();
  List<ShoppingItem> get _unassigned =>
      _items.where((i) => !i.done && (i.shop == null || i.shop!.isEmpty)).toList();

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16, right: 16, bottom: 100,
        ),
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(children: [
            const Text('🛒', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Text('Shopping List', style: TextStyle(
              color: c.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
            const Spacer(),
            // Manage shops
            IconButton(
              onPressed: _openManageShops,
              icon: Icon(Icons.store_rounded, color: c.textSecondary),
              tooltip: 'Manage shops',
            ),
            if (_done.isNotEmpty)
              TextButton(
                onPressed: () async { await _s.clearCompletedShopping(); _load(); },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: Colors.red.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Clear ${_done.length}',
                  style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ]),
          const SizedBox(height: 16),

          // ── Shop sections (pending items) ─────────────────────────────────
          if (_items.where((i) => !i.done).isEmpty && _shops.isEmpty)
            _EmptyState(onAdd: () => _openItemSheet())
          else ...[
            // Shops with items
            ..._shops.asMap().entries.map((entry) {
              final idx   = entry.key;
              final shop  = entry.value;
              final items = _itemsForShop(shop.id);
              return _ShopSection(
                shop: shop,
                color: _shopColor(idx),
                items: items,
                onToggle: (id) => _toggle(id),
                onDelete: (id) => _delete(id),
                onEditItem: (item) => _openItemSheet(item),
                onAddItem: () => _openItemSheet(null, shop.id),
              );
            }),

            // Unassigned items
            if (_unassigned.isNotEmpty)
              _ShopSection(
                shop: ShopModel(id: '', name: 'No shop', emoji: '📦'),
                color: c.textDisabled,
                items: _unassigned,
                onToggle: (id) => _toggle(id),
                onDelete: (id) => _delete(id),
                onEditItem: (item) => _openItemSheet(item),
                onAddItem: () => _openItemSheet(),
              ),

            // Add item FAB row
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _openItemSheet(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: Row(children: [
                  Icon(Icons.add_rounded, color: const Color(0xFF00BFFF), size: 20),
                  const SizedBox(width: 10),
                  Text('Add item', style: TextStyle(
                    color: const Color(0xFF00BFFF), fontSize: 15, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),

            // Done section
            if (_done.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C48C).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_rounded, size: 13, color: Color(0xFF00C48C)),
                ),
                const SizedBox(width: 8),
                Text('IN CART', style: TextStyle(
                  color: const Color(0xFF00C48C), fontSize: 10,
                  fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                const SizedBox(width: 6),
                Text('${_done.length} items', style: TextStyle(color: c.textDisabled, fontSize: 10)),
              ]),
              const SizedBox(height: 8),
              ..._done.map((item) {
                final shopIdx = _shops.indexWhere((s) => s.id == item.shop);
                final color = shopIdx >= 0 ? _shopColor(shopIdx) : c.textDisabled;
                return _ItemTile(
                  item: item, accentColor: color,
                  onToggle: () => _toggle(item.id),
                  onDelete: () => _delete(item.id),
                  onTap: () => _openItemSheet(item),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }
}

// ─── Shop section ─────────────────────────────────────────────────────────────

class _ShopSection extends StatefulWidget {
  final ShopModel shop;
  final Color color;
  final List<ShoppingItem> items;
  final void Function(String) onToggle;
  final void Function(String) onDelete;
  final void Function(ShoppingItem) onEditItem;
  final VoidCallback onAddItem;

  const _ShopSection({
    required this.shop, required this.color, required this.items,
    required this.onToggle, required this.onDelete,
    required this.onEditItem, required this.onAddItem,
  });

  @override
  State<_ShopSection> createState() => _ShopSectionState();
}

class _ShopSectionState extends State<_ShopSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final col = widget.color;
    final shop = widget.shop;
    final items = widget.items;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(color: col.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 4, color: col),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Shop header
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
                    decoration: BoxDecoration(color: col.withValues(alpha: 0.05)),
                    child: Row(children: [
                      Text(shop.emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(shop.name, style: TextStyle(
                          color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                        Text('${items.length} item${items.length == 1 ? '' : 's'} to get',
                          style: TextStyle(color: c.textSecondary, fontSize: 11)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${items.length}', style: TextStyle(
                          color: col, fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 6),
                      Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: c.textDisabled, size: 18),
                    ]),
                  ),
                ),

                // Items
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: _expanded
                      ? Column(children: [
                          if (items.isNotEmpty) Divider(height: 1, color: c.border),
                          ...items.map((item) => Dismissible(
                                key: ValueKey(item.id),
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) => widget.onDelete(item.id),
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 16),
                                  color: Colors.red.withValues(alpha: 0.08),
                                  child: const Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                                ),
                                child: _ItemTile(
                                  item: item, accentColor: col,
                                  onToggle: () => widget.onToggle(item.id),
                                  onDelete: () => widget.onDelete(item.id),
                                  onTap: () => widget.onEditItem(item),
                                ),
                              )),
                          Divider(height: 1, color: c.border),
                          // Add item row
                          InkWell(
                            onTap: widget.onAddItem,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                              child: Row(children: [
                                Icon(Icons.add_rounded, color: col.withValues(alpha: 0.7), size: 16),
                                const SizedBox(width: 8),
                                Text('Add item', style: TextStyle(
                                  color: col.withValues(alpha: 0.7), fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                              ]),
                            ),
                          ),
                        ])
                      : const SizedBox.shrink(),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Item tile ────────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final ShoppingItem item;
  final Color accentColor;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _ItemTile({
    required this.item, required this.accentColor,
    required this.onToggle, required this.onDelete, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        onLongPress: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: item.done ? const Color(0xFF00C48C).withValues(alpha: 0.06) : Colors.transparent,
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: item.done ? const Color(0xFF00C48C) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: item.done ? const Color(0xFF00C48C) : c.border, width: 1.5),
              ),
              child: item.done
                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.label, style: TextStyle(
                color: item.done ? c.textDisabled : c.textPrimary,
                fontSize: 14, fontWeight: FontWeight.w500,
                decoration: item.done ? TextDecoration.lineThrough : null,
                decorationColor: c.textDisabled,
              )),
              if (item.brand != null && item.brand!.isNotEmpty)
                Text(item.brand!, style: TextStyle(
                  color: accentColor.withValues(alpha: 0.8),
                  fontSize: 11, fontWeight: FontWeight.w600)),
            ])),
            Icon(Icons.chevron_right_rounded, color: c.textDisabled, size: 16),
          ]),
        ),
      ),
    );
  }
}

// ─── Add / edit item sheet ────────────────────────────────────────────────────

class _ItemSheet extends StatefulWidget {
  final ShoppingItem? editing;
  final String? preselectedShopId;
  final List<ShopModel> shops;
  final void Function(ShoppingItem) onSave;
  final VoidCallback? onDelete;
  final void Function(ShopModel)? onAddShop;

  const _ItemSheet({
    this.editing,
    this.preselectedShopId,
    required this.shops,
    required this.onSave,
    this.onDelete,
    this.onAddShop,
  });

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _newShopCtrl;
  String? _selectedShopId;
  late List<ShopModel> _shops;
  bool _addingShop = false;
  String _newShopEmoji = '🏪';

  static const _emojis = ['🛒','💊','🥦','🍖','🧴','🏪','💰','🐟','🥐','🌿','🏬','🛍️'];

  @override
  void initState() {
    super.initState();
    _labelCtrl    = TextEditingController(text: widget.editing?.label ?? '');
    _brandCtrl    = TextEditingController(text: widget.editing?.brand ?? '');
    _newShopCtrl  = TextEditingController();
    _shops        = List.from(widget.shops);
    _selectedShopId = widget.editing?.shop ?? widget.preselectedShopId;
  }

  @override
  void dispose() { _labelCtrl.dispose(); _brandCtrl.dispose(); _newShopCtrl.dispose(); super.dispose(); }

  void _saveNewShop(AppColors c) {
    final name = _newShopCtrl.text.trim();
    if (name.isEmpty) return;
    final shop = ShopModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name, emoji: _newShopEmoji,
    );
    widget.onAddShop?.call(shop);
    setState(() {
      _shops.add(shop);
      _selectedShopId = shop.id;
      _addingShop = false;
      _newShopCtrl.clear();
      _newShopEmoji = '🏪';
    });
  }

  void _save() {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) return;
    widget.onSave(ShoppingItem(
      id:    widget.editing?.id ?? StorageService.instance.newId(),
      label: label,
      brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      shop:  _selectedShopId,
      done:  widget.editing?.done ?? false,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    final isEdit = widget.editing != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text(isEdit ? 'Edit item' : 'Add item', style: TextStyle(
            color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          // Item name
          TextField(
            controller: _labelCtrl, autofocus: true,
            style: TextStyle(color: c.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Item name *',
              hintStyle: TextStyle(color: c.textDisabled),
              filled: true, fillColor: c.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 10),

          // Brand
          TextField(
            controller: _brandCtrl,
            style: TextStyle(color: c.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Brand  e.g. Oatly, Optimum Nutrition…',
              hintStyle: TextStyle(color: c.textDisabled, fontSize: 13),
              filled: true, fillColor: c.surfaceHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 14),

          // Shop picker
          Row(children: [
            Text('Shop', style: TextStyle(
              color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() { _addingShop = !_addingShop; }),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_addingShop ? Icons.close_rounded : Icons.add_rounded,
                    color: c.accent, size: 14),
                const SizedBox(width: 3),
                Text(_addingShop ? 'Cancel' : 'New shop',
                    style: TextStyle(color: c.accent, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),

          // Inline add shop
          if (_addingShop) ...[
            Wrap(spacing: 6, runSpacing: 6, children: _emojis.map((e) =>
              GestureDetector(
                onTap: () => setState(() => _newShopEmoji = e),
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: _newShopEmoji == e ? c.accent.withValues(alpha: 0.18) : c.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _newShopEmoji == e ? c.accent : Colors.transparent),
                  ),
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 18))),
                ),
              )).toList()),
            const SizedBox(height: 8),
            Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text(_newShopEmoji, style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                controller: _newShopCtrl,
                autofocus: false,
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Shop name  e.g. BigBasket, Zepto…',
                  hintStyle: TextStyle(color: c.textDisabled, fontSize: 13),
                  filled: true, fillColor: c.surfaceHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _saveNewShop(c),
              )),
              const SizedBox(width: 8),
              Material(
                color: c.accent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => _saveNewShop(c),
                  borderRadius: BorderRadius.circular(8),
                  child: const SizedBox(width: 34, height: 34,
                    child: Icon(Icons.check_rounded, color: Colors.white, size: 18)),
                ),
              ),
            ]),
            const SizedBox(height: 10),
          ],

          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectedShopId = null),
                child: _ShopChip(
                  label: 'None', emoji: '—',
                  color: c.textDisabled,
                  selected: _selectedShopId == null,
                ),
              ),
              ..._shops.asMap().entries.map((e) {
                final shop  = e.value;
                final color = _shopColor(e.key);
                return GestureDetector(
                  onTap: () => setState(() => _selectedShopId = shop.id),
                  child: _ShopChip(
                    label: shop.name, emoji: shop.emoji,
                    color: color,
                    selected: _selectedShopId == shop.id,
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: 20),
          Row(children: [
            if (isEdit && widget.onDelete != null)
              TextButton(
                onPressed: () { widget.onDelete!(); Navigator.pop(context); },
                child: const Text('Delete', style: TextStyle(color: Colors.red))),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: c.textSecondary))),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFFF), foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(isEdit ? 'Save' : 'Add',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _ShopChip extends StatelessWidget {
  final String label;
  final String emoji;
  final Color color;
  final bool selected;
  const _ShopChip({required this.label, required this.emoji, required this.color, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ─── Manage shops sheet ───────────────────────────────────────────────────────

class _ManageShopsSheet extends StatefulWidget {
  final List<ShopModel> shops;
  final void Function(ShopModel) onAdd;
  final void Function(String) onDelete;
  const _ManageShopsSheet({required this.shops, required this.onAdd, required this.onDelete});

  @override
  State<_ManageShopsSheet> createState() => _ManageShopsSheetState();
}

class _ManageShopsSheetState extends State<_ManageShopsSheet> {
  final _nameCtrl  = TextEditingController();
  String _emoji = '🏪';

  final _emojis = ['🛒', '💊', '🥦', '🍖', '🧴', '🏪', '💰', '🐟', '🥐', '🌿'];

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(children: [
          Text('My Shops', style: TextStyle(
            color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const Spacer(),
          TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Done', style: TextStyle(color: c.accent, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),

        // Existing shops
        ...widget.shops.asMap().entries.map((e) {
          final shop  = e.value;
          final color = _shopColor(e.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(shop.emoji, style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(shop.name, style: TextStyle(
                color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w600))),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () {
                  widget.onDelete(shop.id);
                  setState(() {});
                },
              ),
            ]),
          );
        }),

        Divider(color: c.border),
        const SizedBox(height: 8),

        // Emoji picker
        Wrap(spacing: 8, runSpacing: 8, children: _emojis.map((e) =>
          GestureDetector(
            onTap: () => setState(() => _emoji = e),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _emoji == e ? c.accent.withValues(alpha: 0.15) : c.surfaceHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _emoji == e ? c.accent : Colors.transparent),
              ),
              child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
            ),
          )).toList()),
        const SizedBox(height: 10),

        // Add shop row
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: c.surfaceHigh, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(_emoji, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _nameCtrl,
              style: TextStyle(color: c.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Shop name…',
                hintStyle: TextStyle(color: c.textDisabled),
                filled: true, fillColor: c.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _addShop(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: const Color(0xFF00BFFF),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: _addShop,
              borderRadius: BorderRadius.circular(10),
              child: const SizedBox(width: 40, height: 40,
                child: Icon(Icons.add_rounded, color: Colors.white, size: 22)),
            ),
          ),
        ]),
      ]),
    );
  }

  void _addShop() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    widget.onAdd(ShopModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name, emoji: _emoji,
    ));
    _nameCtrl.clear();
    setState(() => _emoji = '🏪');
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = appColors(context);
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 60),
      const Text('🛒', style: TextStyle(fontSize: 52)),
      const SizedBox(height: 14),
      Text('List is empty', style: TextStyle(
        color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Tap + to add items, 🏪 to manage shops',
        style: TextStyle(color: c.textSecondary, fontSize: 13)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add first item'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00BFFF), foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]));
  }
}
