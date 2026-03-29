import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app/themes/admin_theme.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/providers.dart';

class AdminManageMenuScreen extends ConsumerStatefulWidget {
  const AdminManageMenuScreen({super.key});

  @override
  ConsumerState<AdminManageMenuScreen> createState() =>
      _AdminManageMenuScreenState();
}

class _AdminManageMenuScreenState extends ConsumerState<AdminManageMenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Local state for buffered changes
  final Map<String, MenuItemModel> _pendingItems = {};
  final Set<String> _pendingItemDeletes = {};
  
  final Map<String, CategoryModel> _pendingCategories = {};
  final Set<String> _pendingCategoryDeletes = {};

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.background,
      appBar: AppBar(
        title: Text(
          'Manage Menu',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AdminTheme.primary,
          unselectedLabelColor: AdminTheme.textSecondary,
          indicatorColor: AdminTheme.primary,
          tabs: const [
            Tab(text: 'Items'),
            Tab(text: 'Categories'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildItemsTab(), _buildCategoriesTab()],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildItemsTab() {
    final itemsAsync = ref.watch(menuItemsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return itemsAsync.when(
      data: (streamItems) {
        // Use available categories from stream or buffer, or default to empty if loading
        final streamCategories = categoriesAsync.value ?? [];
        
        // Apply Categories Buffer
        final displayCategories = streamCategories
            .where((c) => !_pendingCategoryDeletes.contains(c.id))
            .map((c) => _pendingCategories[c.id] ?? c)
            .toList();
        displayCategories.addAll(
            _pendingCategories.values.where((c) => c.id.startsWith('new_')));

        // Apply Items Buffer
        final displayItems = streamItems
            .where((item) => !_pendingItemDeletes.contains(item.id))
            .map((item) => _pendingItems[item.id] ?? item)
            .toList();
        displayItems.addAll(
            _pendingItems.values.where((item) => item.id.startsWith('new_')));

        if (displayItems.isEmpty) return _buildEmptyState('No items found', Icons.fastfood);

        return Column(
          children: [
            if (categoriesAsync.isLoading)
              const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                color: AdminTheme.primary,
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = constraints.maxWidth > 900 ? 5 : constraints.maxWidth > 600 ? 3 : 2;
                  
                  return GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: displayItems.length,
                    itemBuilder: (context, index) => _buildItemCard(displayItems[index], displayCategories),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildCategoriesTab() {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    return categoriesAsync.when(
      data: (streamCategories) {
        final displayCategories = streamCategories
            .where((c) => !_pendingCategoryDeletes.contains(c.id))
            .map((c) => _pendingCategories[c.id] ?? c)
            .toList();
        displayCategories.addAll(
            _pendingCategories.values.where((c) => c.id.startsWith('new_')));
            
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add New Category Section Mimic
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey[100]!),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Category',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AdminTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _showCategoryDialog(null),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.add_circle_outline, color: Colors.grey[400], size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    'e.g., Vegan Specials, Desserts...',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.grey[500],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showCategoryDialog(null),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Category'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            shadowColor: AdminTheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Active Categories Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Categories',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AdminTheme.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${displayCategories.length} Total',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Category List
              if (displayCategories.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: _buildEmptyState('No categories found', Icons.category),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayCategories.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildCategoryCard(displayCategories[index]),
                ),
              
              // Info Box
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[100]!.withValues(alpha: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[500], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Category Visibility',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[800],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Only active categories with at least one active item will be visible to customers on the ordering app. You can modify the display order using the edit option.',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.blue[800]!.withValues(alpha: 0.8),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildItemCard(MenuItemModel item, List<CategoryModel> availableCategories) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF302F2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    item.imageUrl != null && item.imageUrl!.isNotEmpty
                        ? Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey[100],
                              child: const Icon(Icons.fastfood,
                                  color: Colors.grey, size: 40),
                            ),
                          )
                        : Container(
                            color: Colors.black26,
                            child: const Icon(Icons.fastfood,
                                color: Colors.white24, size: 40),
                          ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '₹${item.price.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: () => _showItemDialog(item, availableCategories),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Details Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                if (item.isPreReady) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      'PRE-READY',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.blue[700],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  item.categoryNames.isNotEmpty 
                      ? item.categoryNames.join(', ')
                      : (availableCategories.where((c) => c.id == item.categoryId).map((e) => e.name).firstOrNull ?? 'Unknown Category'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Actions Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () => _confirmDeleteItem(item),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.delete_outline,
                        size: 20, color: Colors.red[300]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(CategoryModel category) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.drag_indicator, color: Colors.grey[300], size: 20),
          const SizedBox(width: 16),
          // Category Icon Background
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AdminTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.category_outlined, color: AdminTheme.primary),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AdminTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Order: ${category.order}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    if (category.isPreReady) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Text(
                          'PRE-READY',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.edit_outlined, color: Colors.grey[400]),
                onPressed: () => _showCategoryDialog(category),
                splashRadius: 24,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                onPressed: () => _confirmDeleteCategory(category),
                splashRadius: 24,
              ),
              Container(
                width: 1,
                height: 24,
                color: Colors.grey[200],
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              Switch.adaptive(
                value: category.isActive,
                activeThumbColor: AdminTheme.primary,
                onChanged: (v) {
                  setState(() {
                    _pendingCategories[category.id] = category.copyWith(isActive: v);
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AdminTheme.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(color: AdminTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AdminTheme.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (_tabController.index == 0) {
                      final categories = ref.read(categoriesStreamProvider).valueOrNull ?? [];
                      _showItemDialog(null, categories.isEmpty ? null : categories);
                    } else {
                      _showCategoryDialog(null);
                    }
                  },
                  icon: const Icon(Icons.add, size: 20),
                  label: Text(
                    _tabController.index == 0 ? 'Add New Item' : 'Add Category',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminTheme.primary,
                    side: const BorderSide(color: AdminTheme.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () => _confirmChanges(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Confirm Changes',
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemDialog(MenuItemModel? item, [List<CategoryModel>? availableCategories]) {
    // Always try to get categories from provider if none were passed
    final categories = availableCategories ?? ref.read(categoriesStreamProvider).valueOrNull ?? [];
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No categories found. Please add a category first.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => _ItemEditDialog(
        item: item,
        availableCategories: categories,
        onSave: (newItem) {
          setState(() {
            _pendingItems[newItem.id] = newItem;
            _pendingItemDeletes.remove(newItem.id);
          });
        },
      ),
    );
  }

  void _showCategoryDialog(CategoryModel? category) {
    showDialog(
      context: context,
      builder: (context) => _CategoryEditDialog(
        category: category,
        onSave: (newCategory) {
          setState(() {
            _pendingCategories[newCategory.id] = newCategory;
            _pendingCategoryDeletes.remove(newCategory.id);
          });
        },
      ),
    );
  }

  void _confirmDeleteItem(MenuItemModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text(
          'Are you sure you want to delete "${item.name}" from the menu?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _pendingItemDeletes.add(item.id);
                _pendingItems.remove(item.id);
              });
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(CategoryModel category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text(
          'Are you sure you want to delete "${category.name}"? Items in this category will remain but their category label will be outdated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(firestoreServiceProvider)
                  .deleteCategory('default', category.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  Future<void> _confirmChanges(BuildContext context) async {
    setState(() => _isSaving = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final firestoreService = ref.read(firestoreServiceProvider);
      
      // Category Deletes
      for (final id in _pendingCategoryDeletes) {
        if (!id.startsWith('new_')) {
          batch.delete(firestoreService.canteensCollection.doc('default').collection('categories').doc(id));
        }
      }
      
      // Item Deletes
      for (final id in _pendingItemDeletes) {
        if (!id.startsWith('new_')) {
          batch.delete(firestoreService.canteensCollection.doc('default').collection('menuItems').doc(id));
        }
      }
      
      // Category Updates/Adds
      for (final category in _pendingCategories.values) {
        final docRef = category.id.startsWith('new_')
            ? firestoreService.canteensCollection.doc('default').collection('categories').doc()
            : firestoreService.canteensCollection.doc('default').collection('categories').doc(category.id);
            
        batch.set(docRef, category.toMap(), SetOptions(merge: true));
      }
      
      // Item Updates/Adds
      for (final item in _pendingItems.values) {
        final docRef = item.id.startsWith('new_')
            ? firestoreService.canteensCollection.doc('default').collection('menuItems').doc()
            : firestoreService.canteensCollection.doc('default').collection('menuItems').doc(item.id);
            
        batch.set(docRef, item.toMap(), SetOptions(merge: true));
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes saved successfully!')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving changes: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _ItemEditDialog extends ConsumerStatefulWidget {
  final MenuItemModel? item;
  final List<CategoryModel> availableCategories;
  final Function(MenuItemModel) onSave;

  const _ItemEditDialog({
    this.item,
    required this.availableCategories,
    required this.onSave,
  });

  @override
  ConsumerState<_ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends ConsumerState<_ItemEditDialog> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  List<String> _selectedCategoryIds = [];
  bool _isGlobal = false;
  bool _isPreReady = false;
  File? _imageFile;
  final _imagePicker = ImagePicker();
  bool _isUploading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _priceController.text = widget.item!.price.toString();
      _descController.text = widget.item!.description;
      if (widget.item!.categoryIds.isNotEmpty) {
        _selectedCategoryIds = List.from(widget.item!.categoryIds);
      } else if (widget.item!.categoryId.isNotEmpty) {
        _selectedCategoryIds = [widget.item!.categoryId];
      }
      _isGlobal = widget.item!.isGlobal;
      _isPreReady = widget.item!.isPreReady;
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB), // matches background from s9
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item == null ? 'Add New Food Item' : 'Edit Food Item',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Colors.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fill in the details for this dish on your menu.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    splashRadius: 24,
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Base Info Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey[100]!),
                        boxShadow: const [
                          BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildInput(
                                  label: 'Item Name',
                                  controller: _nameController,
                                  hint: 'e.g. Butter Chicken Bowl',
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _buildInput(
                                  label: 'Price (₹)',
                                  controller: _priceController,
                                  hint: '0.00',
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildInput(
                            label: 'Description (Optional)',
                            controller: _descController,
                            hint: 'Brief description of the item',
                            maxLines: 2,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Categories',
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.availableCategories.where((c) => c.isActive).map((c) {
                              final isSelected = _selectedCategoryIds.contains(c.id);
                              return FilterChip(
                                label: Text(c.name, style: GoogleFonts.plusJakartaSans()),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedCategoryIds.add(c.id);
                                    } else {
                                      _selectedCategoryIds.remove(c.id);
                                    }
                                  });
                                },
                                selectedColor: AdminTheme.primary.withValues(alpha: 0.1),
                                checkmarkColor: AdminTheme.primary,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Global Availability Toggle
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey[100]!),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: Text(
                              'Make it available to all sessions',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            subtitle: Text(
                              'Items like juice/ice cream available in all sessions.',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[500]),
                            ),
                            value: _isGlobal,
                            onChanged: (v) => setState(() => _isGlobal = v),
                            activeThumbColor: AdminTheme.primary,
                          ),
                          Divider(height: 1, color: Colors.grey[100]),
                          SwitchListTile(
                            title: Text(
                              'Is already ready?',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            subtitle: Text(
                              'Ready-made items (ice-cream, juice) skip preparation.',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[500]),
                            ),
                            value: _isPreReady,
                            onChanged: (v) => setState(() => _isPreReady = v),
                            activeThumbColor: AdminTheme.primary,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Image Upload Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey[100]!),
                        boxShadow: const [
                          BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FOOD IMAGE',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.grey[200]!, width: 2),
                              ),
                              child: _isUploading
                                  ? const Center(child: CircularProgressIndicator())
                                  : _imageFile != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Center(
                                        child: Image.file(_imageFile!, height: 120, fit: BoxFit.cover),
                                      ),
                                    )
                                  : widget.item?.imageUrl != null && widget.item!.imageUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Center(
                                        child: Image.network(
                                          widget.item!.imageUrl!,
                                          height: 120,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const Icon(Icons.fastfood, size: 40, color: Colors.grey),
                                        ),
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 64,
                                          height: 64,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(color: Color(0x0A000000), blurRadius: 10),
                                            ],
                                          ),
                                          child: const Icon(Icons.photo_camera_rounded, color: AdminTheme.primary, size: 28),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Click or tap to upload',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'PNG, JPG up to 5MB',
                                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[400]),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Save Button Footer
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: ElevatedButton(
                onPressed: _isUploading
                    ? null
                    : () async {
                        if (_nameController.text.trim().isEmpty) return;
                        if (_selectedCategoryIds.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one category')));
                          return;
                        }

                        setState(() => _isUploading = true);

                        try {
                          String? imageUrl = widget.item?.imageUrl;

                          if (_imageFile != null) {
                            imageUrl = await ref
                                .read(firestoreServiceProvider)
                                .uploadMenuItemImage(_imageFile!, 'default');
                          }

                          final categoryNames = widget.availableCategories
                              .where((c) => _selectedCategoryIds.contains(c.id))
                              .map((c) => c.name)
                              .toList();

                          final newItem = MenuItemModel(
                            id: widget.item?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}',
                            name: _nameController.text.trim(),
                            description: _descController.text.trim(),
                            price: double.tryParse(_priceController.text) ?? 0.0,
                            categoryId: _selectedCategoryIds.first,
                            category: categoryNames.isNotEmpty ? categoryNames.first : '',
                            categoryIds: _selectedCategoryIds,
                            categoryNames: categoryNames,
                            imageUrl: imageUrl,
                            isAvailable: widget.item?.isAvailable ?? true,
                            isGlobal: _isGlobal,
                            isPreReady: _isPreReady,
                            createdAt: widget.item?.createdAt ?? DateTime.now(),
                            updatedAt: DateTime.now(),
                          );

                          widget.onSave(newItem);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error saving item: $e')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isUploading = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                ),
                child: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Save Item',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.black),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.black),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryEditDialog extends ConsumerStatefulWidget {
  final CategoryModel? category;
  final Function(CategoryModel) onSave;

  const _CategoryEditDialog({this.category, required this.onSave});

  @override
  ConsumerState<_CategoryEditDialog> createState() =>
      _CategoryEditDialogState();
}

class _CategoryEditDialogState extends ConsumerState<_CategoryEditDialog> {
  final _nameController = TextEditingController();
  final _orderController = TextEditingController();
  bool _isPreReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _orderController.text = widget.category!.order.toString();
      _isPreReady = widget.category!.isPreReady;
    } else {
      _orderController.text = '0';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[100]!),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.category == null ? 'Add Category' : 'Edit Category',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: AdminTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Define category details and display order',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDialogInput(
                    label: 'Category Name',
                    controller: _nameController,
                    hint: 'e.g., Hot Meals',
                    icon: Icons.category_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildDialogInput(
                    label: 'Display Order',
                    controller: _orderController,
                    hint: 'e.g., 1',
                    icon: Icons.sort,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[100]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Is Pre-Ready / Already Ready?',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AdminTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Items in this category skip preparation flow by default.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _isPreReady,
                          activeThumbColor: AdminTheme.primary,
                          onChanged: (val) => setState(() => _isPreReady = val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_nameController.text.trim().isEmpty) return;
                        
                        final newCategory = CategoryModel(
                          id: widget.category?.id ?? 'new_${DateTime.now().millisecondsSinceEpoch}',
                          name: _nameController.text.trim(),
                          order: int.tryParse(_orderController.text) ?? 0,
                          isActive: widget.category?.isActive ?? true,
                          isPreReady: _isPreReady,
                          createdAt: widget.category?.createdAt ?? DateTime.now(),
                        );
                        widget.onSave(newCategory);
                        if (context.mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        shadowColor: AdminTheme.primary.withValues(alpha: 0.3),
                      ),
                      child: Text(
                        'Save',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogInput({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AdminTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey[400]),
            prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdminTheme.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
