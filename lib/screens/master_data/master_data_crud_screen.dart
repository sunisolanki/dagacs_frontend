import 'package:flutter/material.dart';

import '../../core/theme/dagacs_theme.dart';
import '../../network/api_exception.dart';
import '../../widgets/dagacs_widgets.dart';

/// Generic ADMIN CRUD list for one master-data entity.
///
/// Handles loading / error / empty / pull-to-refresh, create and edit (via the
/// provided callbacks which open the entity form) and a user-confirmed delete.
/// The backend stays authoritative: every mutation goes through
/// `MasterDataRepository` and non-2xx responses (e.g. a 409 referential
/// conflict) are surfaced via [userMessageFor].
class MasterDataCrudScreen<T> extends StatefulWidget {
  const MasterDataCrudScreen({
    super.key,
    required this.title,
    required this.entityKey,
    required this.icon,
    required this.addTooltip,
    required this.emptyText,
    required this.idOf,
    required this.titleOf,
    required this.fetch,
    required this.create,
    required this.edit,
    required this.remove,
    this.subtitleOf,
  });

  final String title;
  final String entityKey;
  final IconData icon;
  final String addTooltip;
  final String emptyText;
  final int Function(T item) idOf;
  final String Function(T item) titleOf;
  final String? Function(T item)? subtitleOf;
  final Future<List<T>> Function() fetch;
  final Future<T?> Function(BuildContext context) create;
  final Future<T?> Function(BuildContext context, T item) edit;
  final Future<void> Function(T item) remove;

  @override
  State<MasterDataCrudScreen<T>> createState() =>
      _MasterDataCrudScreenState<T>();
}

class _MasterDataCrudScreenState<T> extends State<MasterDataCrudScreen<T>> {
  List<T> _items = const [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<T> get _visibleItems {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return _items.where((item) {
      final title = widget.titleOf(item).toLowerCase();
      final subtitle = widget.subtitleOf?.call(item)?.toLowerCase() ?? '';
      return title.contains(query) || subtitle.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.fetch();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userMessageFor(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong while loading ${widget.title}.';
        _loading = false;
      });
    }
  }

  Future<void> _openCreate() async {
    final created = await widget.create(context);
    if (created != null && mounted) await _load();
  }

  Future<void> _openEdit(T item) async {
    final updated = await widget.edit(context, item);
    if (updated != null && mounted) await _load();
  }

  Future<void> _confirmDelete(T item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppConfirmDialog(
        title: 'Delete ${widget.title}',
        message: 'Delete "${widget.titleOf(item)}"? This cannot be undone. '
            'Records that are used elsewhere cannot be deleted.',
        confirmKey: Key('${widget.entityKey}-confirm-delete'),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.remove(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "${widget.titleOf(item)}".')),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      final message = e.statusCode == 409
          ? 'Unable to delete this record because it is being used elsewhere.'
          : userMessageFor(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: FloatingActionButton(
        key: Key('${widget.entityKey}-add'),
        tooltip: widget.addTooltip,
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingState(message: 'Loading...');
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }
    if (_items.isEmpty) {
      return AppEmptyState(
        key: Key('${widget.entityKey}-empty'),
        message: widget.emptyText,
      );
    }
    final visible = _visibleItems;
    return RefreshIndicator(
      key: Key('${widget.entityKey}-refresh'),
      onRefresh: _load,
      child: ListView.builder(
        key: Key('${widget.entityKey}-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          DagacsSpace.lg,
          DagacsSpace.sm,
          DagacsSpace.lg,
          96, // clearance for the FAB
        ),
        itemCount: visible.isEmpty ? 3 : visible.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return AppPageHeader(
              icon: widget.icon,
              subtitle: 'Search, add, edit or remove ${widget.title.toLowerCase()}.',
            );
          }
          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                DagacsSpace.lg,
                0,
                DagacsSpace.lg,
                DagacsSpace.lg,
              ),
              child: AppSearchField(
                key: Key('${widget.entityKey}-search'),
                controller: _searchController,
                hintText: 'Search ${widget.title.toLowerCase()}',
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            );
          }
          if (visible.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: DagacsSpace.xxxl),
              child: AppEmptyState(
                icon: Icons.search_off_outlined,
                message: 'No ${widget.title.toLowerCase()} match your search.',
              ),
            );
          }
          final item = visible[index - 2];
          final subtitle = widget.subtitleOf?.call(item);
          return Padding(
            padding: const EdgeInsets.only(bottom: DagacsSpace.sm + 2),
            child: AppCard(
              key: Key('${widget.entityKey}-tile-${widget.idOf(item)}'),
              onTap: () => _openEdit(item),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              child: Row(
                children: [
                  AppIconBadge(icon: widget.icon, size: 46),
                  const SizedBox(width: DagacsSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.titleOf(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (subtitle == null || subtitle.isEmpty)
                          const SizedBox.shrink()
                        else ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: DagacsSpace.sm),
                  IconButton(
                    key: Key(
                        '${widget.entityKey}-edit-${widget.idOf(item)}'),
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _openEdit(item),
                  ),
                  IconButton(
                    key: Key(
                        '${widget.entityKey}-delete-${widget.idOf(item)}'),
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline,
                        color: DagacsColors.error),
                    onPressed: () => _confirmDelete(item),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
