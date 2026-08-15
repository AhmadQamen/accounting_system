import 'package:accounting_system/core/models/model_parsers.dart';

class DashboardMetrics {
  final int cash; final int salesToday; final int purchasesToday; final int customerReceivables; final int supplierPayables; final int inventoryValue; final int lowStock; final int pendingSync;
  const DashboardMetrics({this.cash=0,this.salesToday=0,this.purchasesToday=0,this.customerReceivables=0,this.supplierPayables=0,this.inventoryValue=0,this.lowStock=0,this.pendingSync=0});
}

class SalesReport {
  final int grossSales; final int discounts; final int returns; final int cogs; final int invoiceCount; final int netSales; final int grossProfit;
  const SalesReport({this.grossSales=0,this.discounts=0,this.returns=0,this.cogs=0,this.invoiceCount=0,this.netSales=0,this.grossProfit=0});
  factory SalesReport.fromSql(Map<String,Object?> r){final gross=intValue(r['gross_sales']);final returns=intValue(r['returns']);final cogs=intValue(r['cogs']);return SalesReport(grossSales:gross,discounts:intValue(r['discounts']),returns:returns,cogs:cogs,invoiceCount:intValue(r['invoice_count']),netSales:gross-returns,grossProfit:gross-returns-cogs);}
}
class PurchasesReport {
  final int grossPurchases; final int discounts; final int returns; final int invoiceCount; final int netPurchases;
  const PurchasesReport({this.grossPurchases=0,this.discounts=0,this.returns=0,this.invoiceCount=0,this.netPurchases=0});
  factory PurchasesReport.fromSql(Map<String,Object?> r){final gross=intValue(r['gross_purchases']);final returns=intValue(r['returns']);return PurchasesReport(grossPurchases:gross,discounts:intValue(r['discounts']),returns:returns,invoiceCount:intValue(r['invoice_count']),netPurchases:gross-returns);}
}
class InventoryBalanceReport {
  final String productName; final String warehouseName; final double currentQuantity; final int inventoryValueMinor; final double minQuantity;
  const InventoryBalanceReport({required this.productName,required this.warehouseName,this.currentQuantity=0,this.inventoryValueMinor=0,this.minQuantity=0});
  bool get isLowStock=>minQuantity>0&&currentQuantity<=minQuantity;
  factory InventoryBalanceReport.fromSql(Map<String,Object?> r)=>InventoryBalanceReport(productName:r['product_name']?.toString()??'',warehouseName:r['warehouse_name']?.toString()??'',currentQuantity:doubleValue(r['current_quantity']),inventoryValueMinor:intValue(r['inventory_value_minor']),minQuantity:doubleValue(r['min_quantity']));
}
class PartyBalanceReport {
  final String id; final String name; final String? phone; final String type; final int currentBalanceMinor;
  const PartyBalanceReport({required this.id,required this.name,this.phone,required this.type,this.currentBalanceMinor=0});
  factory PartyBalanceReport.fromSql(Map<String,Object?> r)=>PartyBalanceReport(id:r['id']?.toString()??'',name:r['name']?.toString()??'',phone:stringOrNull(r['phone']),type:r['type']?.toString()??'customer',currentBalanceMinor:intValue(r['current_balance_minor']));
}
class CashBalanceReport {
  final String id; final String name; final int currentBalanceMinor;
  const CashBalanceReport({required this.id,required this.name,this.currentBalanceMinor=0});
  factory CashBalanceReport.fromSql(Map<String,Object?> r)=>CashBalanceReport(id:r['id']?.toString()??'',name:r['name']?.toString()??'',currentBalanceMinor:intValue(r['current_balance_minor']));
}
class CashFlowReport {
  final int totalIn; final int totalOut; final int netFlow; final int expenses;
  const CashFlowReport({this.totalIn=0,this.totalOut=0,this.netFlow=0,this.expenses=0});
  factory CashFlowReport.fromSql(Map<String,Object?> r)=>CashFlowReport(totalIn:intValue(r['total_in']),totalOut:intValue(r['total_out']),netFlow:intValue(r['net_flow']),expenses:intValue(r['expenses']));
}
class DashboardTrends {
  final List<int> sales; final List<int> purchases;
  const DashboardTrends({this.sales=const[],this.purchases=const[]});
}
class ActivityItem {
  final String kind; final String id; final String displayNumber; final int amountMinor; final DateTime? occurredAt; final String? partyName;
  const ActivityItem({required this.kind,required this.id,required this.displayNumber,this.amountMinor=0,this.occurredAt,this.partyName});
  factory ActivityItem.fromSql(Map<String,Object?> r)=>ActivityItem(kind:r['kind']?.toString()??'',id:r['id']?.toString()??'',displayNumber:r['display_number']?.toString()??'',amountMinor:intValue(r['amount_minor']),occurredAt:parseDate(r['occurred_at']),partyName:stringOrNull(r['party_name']));
}
class LowStockItem {
  final String productId; final String productName; final String warehouseName; final double currentQuantity; final double minQuantity;
  const LowStockItem({required this.productId,required this.productName,required this.warehouseName,this.currentQuantity=0,this.minQuantity=0});
  double get stockRatio=>minQuantity<=0?1:currentQuantity/minQuantity;
  factory LowStockItem.fromSql(Map<String,Object?> r)=>LowStockItem(productId:r['product_id']?.toString()??'',productName:r['product_name']?.toString()??'',warehouseName:r['warehouse_name']?.toString()??'',currentQuantity:doubleValue(r['current_quantity']),minQuantity:doubleValue(r['min_quantity']));
}

class DashboardData {
  final DashboardMetrics metrics;
  final DashboardTrends trends;
  final List<ActivityItem> recentActivity;
  final List<LowStockItem> lowStockItems;

  const DashboardData({
    required this.metrics,
    required this.trends,
    this.recentActivity = const [],
    this.lowStockItems = const [],
  });
}

class CashReportData {
  final List<CashBalanceReport> balances;
  final CashFlowReport flow;

  const CashReportData({required this.balances, required this.flow});
}

class DailyTotal {
  final String day;
  final int totalMinor;

  const DailyTotal({required this.day, this.totalMinor = 0});

  factory DailyTotal.fromSql(Map<String, Object?> row) => DailyTotal(
        day: row['day']?.toString() ?? '',
        totalMinor: intValue(row['total']),
      );
}
