import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Column definition for AdminTable
class AdminTableColumn {
  final String label;
  final String field;
  final double? width;
  final bool sortable;
  final Widget Function(Map<String, dynamic> row)? cellBuilder;
  final TextAlign textAlign;

  const AdminTableColumn({
    required this.label,
    required this.field,
    this.width,
    this.sortable = false,
    this.cellBuilder,
    this.textAlign = TextAlign.left,
  });
}

/// Reusable table widget for Admin Center with pagination
/// Provides consistent table styling and pagination controls
class AdminTable extends StatelessWidget {
  final List<AdminTableColumn> columns;
  final List<Map<String, dynamic>> rows;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;
  final Function(int page) onPageChanged;
  final Function(String field, String order)? onSort;
  final String? sortField;
  final String? sortOrder;
  final bool isLoading;
  final String? emptyMessage;
  final Function(Map<String, dynamic> row)? onRowTap;

  const AdminTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
    required this.onPageChanged,
    this.onSort,
    this.sortField,
    this.sortOrder,
    this.isLoading = false,
    this.emptyMessage,
    this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 768;

    if (isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingXL),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingXL),
          child: Text(
            emptyMessage ?? 'No data available',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.textColorLight,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Table
        if (isSmallScreen)
          _buildMobileTable(context)
        else
          _buildDesktopTable(context),

        SizedBox(height: AppTheme.spacingM),

        // Pagination
        _buildPagination(context),
      ],
    );
  }

  Widget _buildDesktopTable(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          AppTheme.backgroundCard.withValues(alpha: 0.5),
        ),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return AppTheme.primaryColor.withValues(alpha: 0.1);
          }
          return null;
        }),
        columns: columns.map((column) {
          return DataColumn(
            label: Text(
              column.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
            onSort: column.sortable && onSort != null
                ? (columnIndex, ascending) {
                    onSort!(column.field, ascending ? 'asc' : 'desc');
                  }
                : null,
          );
        }).toList(),
        rows: rows.map((row) {
          return DataRow(
            onSelectChanged: onRowTap != null ? (_) => onRowTap!(row) : null,
            cells: columns.map((column) {
              final value = row[column.field];
              return DataCell(
                column.cellBuilder != null
                    ? column.cellBuilder!(row)
                    : Text(
                        value?.toString() ?? '',
                        style: theme.textTheme.bodyMedium,
                        textAlign: column.textAlign,
                      ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileTable(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return Card(
          margin: EdgeInsets.symmetric(
            vertical: AppTheme.spacingS,
            horizontal: AppTheme.spacingM,
          ),
          child: InkWell(
            onTap: onRowTap != null ? () => onRowTap!(row) : null,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: columns.map((column) {
                  final value = row[column.field];
                  return Padding(
                    padding: EdgeInsets.only(bottom: AppTheme.spacingS),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            column.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textColorLight,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: column.cellBuilder != null
                              ? column.cellBuilder!(row)
                              : Text(
                                  value?.toString() ?? '',
                                  style: theme.textTheme.bodyMedium,
                                  textAlign: column.textAlign,
                                ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPagination(BuildContext context) {
    final theme = Theme.of(context);
    final startItem = (currentPage - 1) * itemsPerPage + 1;
    final endItem = (currentPage * itemsPerPage).clamp(0, totalItems);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Items info
        Text(
          'Showing $startItem-$endItem of $totalItems items',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textColorLight,
          ),
        ),

        // Page controls
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left),
              onPressed:
                  currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
              tooltip: 'Previous page',
            ),
            Text(
              'Page $currentPage of $totalPages',
              style: theme.textTheme.bodyMedium,
            ),
            IconButton(
              icon: Icon(Icons.chevron_right),
              onPressed: currentPage < totalPages
                  ? () => onPageChanged(currentPage + 1)
                  : null,
              tooltip: 'Next page',
            ),
          ],
        ),
      ],
    );
  }
}
