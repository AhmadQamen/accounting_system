import 'package:accounting_system/core/configs/unset.dart';
import 'package:accounting_system/core/configs/uuid.dart';
import 'package:accounting_system/core/domain/money.dart';
import 'package:accounting_system/core/models/model_parsers.dart';

class AccountingDocument {
  final String? id;
  final String type;
  final String displayNumber;
  final String? partyId;
  final String? partyName;
  final String status;
  final int subtotalMinor;
  final int discountMinor;
  final int finalMinor;
  final int paidMinor;
  final int refundedMinor;
  final int totalCostMinor;
  final String? cashboxId;
  final String? note;
  final DateTime? occurredAt;
  final DateTime? postedAt;
  final DateTime? voidedAt;
  final int version;

  const AccountingDocument({this.id,required this.type,required this.displayNumber,this.partyId,this.partyName,this.status='draft',this.subtotalMinor=0,this.discountMinor=0,this.finalMinor=0,this.paidMinor=0,this.refundedMinor=0,this.totalCostMinor=0,this.cashboxId,this.note,this.occurredAt,this.postedAt,this.voidedAt,this.version=1});

  int get displayTotalMinor => type == 'waste' ? totalCostMinor : finalMinor;
  bool get isDraft => status == 'draft';
  bool get isPosted => status == 'posted';
  bool get isVoid => status == 'void';

  factory AccountingDocument.fromSql(Map<String,Object?> r,{required String type})=>AccountingDocument(
    id:stringOrNull(r['id']),type:type,
    displayNumber:(r['display_number']??r['invoice_number']??r['return_number']??r['waste_number']??r['id'])?.toString()??'',
    partyId:stringOrNull(r['party_id']),partyName:stringOrNull(r['party_name']),status:r['status']?.toString()??'draft',subtotalMinor:intValue(r['subtotal_minor']),discountMinor:intValue(r['discount_minor']),finalMinor:intValue(r['final_minor']),paidMinor:intValue(r['paid_minor']),refundedMinor:intValue(r['refunded_minor']),totalCostMinor:intValue(r['total_cost_minor']),cashboxId:stringOrNull(r['cashbox_id']),note:stringOrNull(r['note']),occurredAt:parseDate(r['occurred_at']),postedAt:parseDate(r['posted_at']),voidedAt:parseDate(r['voided_at']),version:intValue(r['version'],1));
  factory AccountingDocument.fromJson(Map<String,dynamic> r)=>AccountingDocument(id:stringOrNull(r['id']),type:r['type']?.toString()??'',displayNumber:(r['displayNumber']??r['display_number'])?.toString()??'',partyId:stringOrNull(r['partyId']??r['party_id']),partyName:stringOrNull(r['partyName']??r['party_name']),status:r['status']?.toString()??'draft',subtotalMinor:intValue(r['subtotalMinor']??r['subtotal_minor']),discountMinor:intValue(r['discountMinor']??r['discount_minor']),finalMinor:intValue(r['finalMinor']??r['final_minor']),paidMinor:intValue(r['paidMinor']??r['paid_minor']),refundedMinor:intValue(r['refundedMinor']??r['refunded_minor']),totalCostMinor:intValue(r['totalCostMinor']??r['total_cost_minor']),cashboxId:stringOrNull(r['cashboxId']??r['cashbox_id']),note:stringOrNull(r['note']),occurredAt:parseDate(r['occurredAt']??r['occurred_at']),postedAt:parseDate(r['postedAt']??r['posted_at']),voidedAt:parseDate(r['voidedAt']??r['voided_at']),version:intValue(r['version'],1));
  Map<String,dynamic> toJson()=>{if(id!=null)'id':id,'type':type,'displayNumber':displayNumber,'partyId':partyId,'partyName':partyName,'status':status,'subtotalMinor':subtotalMinor,'discountMinor':discountMinor,'finalMinor':finalMinor,'paidMinor':paidMinor,'refundedMinor':refundedMinor,'totalCostMinor':totalCostMinor,'cashboxId':cashboxId,'note':note,'occurredAt':isoUtc(occurredAt),'postedAt':isoUtc(postedAt),'voidedAt':isoUtc(voidedAt),'version':version};
  AccountingDocument copyWith({Object?id=unset,Object?type=unset,Object?displayNumber=unset,Object?partyId=unset,Object?partyName=unset,Object?status=unset,Object?subtotalMinor=unset,Object?discountMinor=unset,Object?finalMinor=unset,Object?paidMinor=unset,Object?refundedMinor=unset,Object?totalCostMinor=unset,Object?cashboxId=unset,Object?note=unset,Object?occurredAt=unset,Object?postedAt=unset,Object?voidedAt=unset,Object?version=unset})=>AccountingDocument(id:id is Unset?this.id:id as String?,type:type is Unset?this.type:type as String,displayNumber:displayNumber is Unset?this.displayNumber:displayNumber as String,partyId:partyId is Unset?this.partyId:partyId as String?,partyName:partyName is Unset?this.partyName:partyName as String?,status:status is Unset?this.status:status as String,subtotalMinor:subtotalMinor is Unset?this.subtotalMinor:subtotalMinor as int,discountMinor:discountMinor is Unset?this.discountMinor:discountMinor as int,finalMinor:finalMinor is Unset?this.finalMinor:finalMinor as int,paidMinor:paidMinor is Unset?this.paidMinor:paidMinor as int,refundedMinor:refundedMinor is Unset?this.refundedMinor:refundedMinor as int,totalCostMinor:totalCostMinor is Unset?this.totalCostMinor:totalCostMinor as int,cashboxId:cashboxId is Unset?this.cashboxId:cashboxId as String?,note:note is Unset?this.note:note as String?,occurredAt:occurredAt is Unset?this.occurredAt:occurredAt as DateTime?,postedAt:postedAt is Unset?this.postedAt:postedAt as DateTime?,voidedAt:voidedAt is Unset?this.voidedAt:voidedAt as DateTime?,version:version is Unset?this.version:version as int);
}

class DocumentLine {
  final String? id; final String? inventoryItemId; final String? productUnitId; final String? productName; final String? unitName; final double quantity; final double unitFactor; final double baseQuantity; final int unitPriceMinor; final int unitCostMinor; final int lineDiscountMinor; final int lineTotalMinor; final int costAmountMinor;
  const DocumentLine({this.id,this.inventoryItemId,this.productUnitId,this.productName,this.unitName,this.quantity=0,this.unitFactor=1,this.baseQuantity=0,this.unitPriceMinor=0,this.unitCostMinor=0,this.lineDiscountMinor=0,this.lineTotalMinor=0,this.costAmountMinor=0});
  factory DocumentLine.fromSql(Map<String,Object?> r)=>DocumentLine(id:stringOrNull(r['id']),inventoryItemId:stringOrNull(r['inventory_item_id']),productUnitId:stringOrNull(r['product_unit_id']),productName:stringOrNull(r['product_name']),unitName:stringOrNull(r['unit_name']),quantity:doubleValue(r['quantity']),unitFactor:doubleValue(r['unit_factor_at_sale']??r['unit_factor_at_purchase']??r['unit_factor_at_return']??r['unit_factor_at_waste'],1),baseQuantity:doubleValue(r['base_quantity']),unitPriceMinor:intValue(r['unit_price_minor']),unitCostMinor:intValue(r['unit_cost_minor']),lineDiscountMinor:intValue(r['line_discount_minor']),lineTotalMinor:intValue(r['line_total_minor']),costAmountMinor:intValue(r['cost_amount_minor']));
  factory DocumentLine.fromJson(Map<String,dynamic> r)=>DocumentLine(id:stringOrNull(r['id']),inventoryItemId:stringOrNull(r['inventoryItemId']??r['inventory_item_id']),productUnitId:stringOrNull(r['productUnitId']??r['product_unit_id']),productName:stringOrNull(r['productName']??r['product_name']),unitName:stringOrNull(r['unitName']??r['unit_name']),quantity:doubleValue(r['quantity']),unitFactor:doubleValue(r['unitFactor']??r['unit_factor'],1),baseQuantity:doubleValue(r['baseQuantity']??r['base_quantity']),unitPriceMinor:intValue(r['unitPriceMinor']??r['unit_price_minor']),unitCostMinor:intValue(r['unitCostMinor']??r['unit_cost_minor']),lineDiscountMinor:intValue(r['lineDiscountMinor']??r['line_discount_minor']),lineTotalMinor:intValue(r['lineTotalMinor']??r['line_total_minor']),costAmountMinor:intValue(r['costAmountMinor']??r['cost_amount_minor']));
  Map<String,dynamic> toJson()=>{if(id!=null)'id':id,'inventoryItemId':inventoryItemId,'productUnitId':productUnitId,'productName':productName,'unitName':unitName,'quantity':quantity,'unitFactor':unitFactor,'baseQuantity':baseQuantity,'unitPriceMinor':unitPriceMinor,'unitCostMinor':unitCostMinor,'lineDiscountMinor':lineDiscountMinor,'lineTotalMinor':lineTotalMinor,'costAmountMinor':costAmountMinor};
  DocumentLine copyWith({Object?id=unset,Object?inventoryItemId=unset,Object?productUnitId=unset,Object?productName=unset,Object?unitName=unset,Object?quantity=unset,Object?unitFactor=unset,Object?baseQuantity=unset,Object?unitPriceMinor=unset,Object?unitCostMinor=unset,Object?lineDiscountMinor=unset,Object?lineTotalMinor=unset,Object?costAmountMinor=unset})=>DocumentLine(id:id is Unset?this.id:id as String?,inventoryItemId:inventoryItemId is Unset?this.inventoryItemId:inventoryItemId as String?,productUnitId:productUnitId is Unset?this.productUnitId:productUnitId as String?,productName:productName is Unset?this.productName:productName as String?,unitName:unitName is Unset?this.unitName:unitName as String?,quantity:quantity is Unset?this.quantity:quantity as double,unitFactor:unitFactor is Unset?this.unitFactor:unitFactor as double,baseQuantity:baseQuantity is Unset?this.baseQuantity:baseQuantity as double,unitPriceMinor:unitPriceMinor is Unset?this.unitPriceMinor:unitPriceMinor as int,unitCostMinor:unitCostMinor is Unset?this.unitCostMinor:unitCostMinor as int,lineDiscountMinor:lineDiscountMinor is Unset?this.lineDiscountMinor:lineDiscountMinor as int,lineTotalMinor:lineTotalMinor is Unset?this.lineTotalMinor:lineTotalMinor as int,costAmountMinor:costAmountMinor is Unset?this.costAmountMinor:costAmountMinor as int);
}

class DocumentDetails {
  final AccountingDocument header; final List<DocumentLine> items;
  const DocumentDetails({required this.header,required this.items});
}

class SaleLineInput {
  final String inventoryItemId; final String productUnitId; final double quantity; final double unitFactor; final int unitPriceMinor; final int lineDiscountMinor;
  const SaleLineInput({required this.inventoryItemId,required this.productUnitId,required this.quantity,required this.unitFactor,required this.unitPriceMinor,this.lineDiscountMinor=0});
  double get baseQuantity=>quantity*unitFactor;
  int get lineTotalMinor=>Money.multiplyByQuantity(unitPriceMinor,quantity)-lineDiscountMinor;
  factory SaleLineInput.fromJson(Map<String,dynamic> r)=>SaleLineInput(inventoryItemId:(r['inventoryItemId']??r['inventory_item_id'])?.toString()??'',productUnitId:(r['productUnitId']??r['product_unit_id'])?.toString()??'',quantity:doubleValue(r['quantity']),unitFactor:doubleValue(r['unitFactor']??r['unit_factor'],1),unitPriceMinor:intValue(r['unitPriceMinor']??r['unit_price_minor']),lineDiscountMinor:intValue(r['lineDiscountMinor']??r['line_discount_minor']));
  Map<String,Object?> toSql({required String entityId,required String saleId,required DateTime now})=>{'id':uuid.v4(),'entity_id':entityId,'sale_id':saleId,'inventory_item_id':inventoryItemId,'product_unit_id':productUnitId,'quantity':quantity,'unit_factor_at_sale':unitFactor,'base_quantity':baseQuantity,'unit_price_minor':unitPriceMinor,'line_discount_minor':lineDiscountMinor,'line_total_minor':lineTotalMinor,'net_amount_minor':0,'cost_amount_minor':0,'created_at':now.toIso8601String(),'updated_at':now.toIso8601String()};
  Map<String,dynamic> toJson()=>{'inventoryItemId':inventoryItemId,'productUnitId':productUnitId,'quantity':quantity,'unitFactor':unitFactor,'unitPriceMinor':unitPriceMinor,'lineDiscountMinor':lineDiscountMinor,'baseQuantity':baseQuantity,'lineTotalMinor':lineTotalMinor};
  SaleLineInput copyWith({Object?inventoryItemId=unset,Object?productUnitId=unset,Object?quantity=unset,Object?unitFactor=unset,Object?unitPriceMinor=unset,Object?lineDiscountMinor=unset})=>SaleLineInput(inventoryItemId:inventoryItemId is Unset?this.inventoryItemId:inventoryItemId as String,productUnitId:productUnitId is Unset?this.productUnitId:productUnitId as String,quantity:quantity is Unset?this.quantity:quantity as double,unitFactor:unitFactor is Unset?this.unitFactor:unitFactor as double,unitPriceMinor:unitPriceMinor is Unset?this.unitPriceMinor:unitPriceMinor as int,lineDiscountMinor:lineDiscountMinor is Unset?this.lineDiscountMinor:lineDiscountMinor as int);
}

class PurchaseLineInput {
  final String inventoryItemId; final String productUnitId; final double quantity; final double unitFactor; final int unitCostMinor; final int lineDiscountMinor;
  const PurchaseLineInput({required this.inventoryItemId,required this.productUnitId,required this.quantity,required this.unitFactor,required this.unitCostMinor,this.lineDiscountMinor=0});
  double get baseQuantity=>quantity*unitFactor;
  int get lineTotalMinor=>Money.multiplyByQuantity(unitCostMinor,quantity)-lineDiscountMinor;
  factory PurchaseLineInput.fromJson(Map<String,dynamic> r)=>PurchaseLineInput(inventoryItemId:(r['inventoryItemId']??r['inventory_item_id'])?.toString()??'',productUnitId:(r['productUnitId']??r['product_unit_id'])?.toString()??'',quantity:doubleValue(r['quantity']),unitFactor:doubleValue(r['unitFactor']??r['unit_factor'],1),unitCostMinor:intValue(r['unitCostMinor']??r['unit_cost_minor']),lineDiscountMinor:intValue(r['lineDiscountMinor']??r['line_discount_minor']));
  Map<String,Object?> toSql({required String entityId,required String purchaseId,required DateTime now})=>{'id':uuid.v4(),'entity_id':entityId,'purchase_invoice_id':purchaseId,'inventory_item_id':inventoryItemId,'product_unit_id':productUnitId,'quantity':quantity,'unit_factor_at_purchase':unitFactor,'base_quantity':baseQuantity,'unit_cost_minor':unitCostMinor,'line_discount_minor':lineDiscountMinor,'line_total_minor':lineTotalMinor,'cost_amount_minor':0,'created_at':now.toIso8601String(),'updated_at':now.toIso8601String()};
  Map<String,dynamic> toJson()=>{'inventoryItemId':inventoryItemId,'productUnitId':productUnitId,'quantity':quantity,'unitFactor':unitFactor,'unitCostMinor':unitCostMinor,'lineDiscountMinor':lineDiscountMinor,'baseQuantity':baseQuantity,'lineTotalMinor':lineTotalMinor};
  PurchaseLineInput copyWith({Object?inventoryItemId=unset,Object?productUnitId=unset,Object?quantity=unset,Object?unitFactor=unset,Object?unitCostMinor=unset,Object?lineDiscountMinor=unset})=>PurchaseLineInput(inventoryItemId:inventoryItemId is Unset?this.inventoryItemId:inventoryItemId as String,productUnitId:productUnitId is Unset?this.productUnitId:productUnitId as String,quantity:quantity is Unset?this.quantity:quantity as double,unitFactor:unitFactor is Unset?this.unitFactor:unitFactor as double,unitCostMinor:unitCostMinor is Unset?this.unitCostMinor:unitCostMinor as int,lineDiscountMinor:lineDiscountMinor is Unset?this.lineDiscountMinor:lineDiscountMinor as int);
}

class WasteLineInput {
  final String inventoryItemId; final String productUnitId; final double quantity; final double unitFactor;
  const WasteLineInput({required this.inventoryItemId,required this.productUnitId,required this.quantity,required this.unitFactor});
  double get baseQuantity=>quantity*unitFactor;
  factory WasteLineInput.fromJson(Map<String,dynamic> r)=>WasteLineInput(inventoryItemId:(r['inventoryItemId']??r['inventory_item_id'])?.toString()??'',productUnitId:(r['productUnitId']??r['product_unit_id'])?.toString()??'',quantity:doubleValue(r['quantity']),unitFactor:doubleValue(r['unitFactor']??r['unit_factor'],1));
  Map<String,dynamic> toJson()=>{'inventoryItemId':inventoryItemId,'productUnitId':productUnitId,'quantity':quantity,'unitFactor':unitFactor,'baseQuantity':baseQuantity};
  WasteLineInput copyWith({Object?inventoryItemId=unset,Object?productUnitId=unset,Object?quantity=unset,Object?unitFactor=unset})=>WasteLineInput(inventoryItemId:inventoryItemId is Unset?this.inventoryItemId:inventoryItemId as String,productUnitId:productUnitId is Unset?this.productUnitId:productUnitId as String,quantity:quantity is Unset?this.quantity:quantity as double,unitFactor:unitFactor is Unset?this.unitFactor:unitFactor as double);
}

class ReturnLineInput {
  final String originalItemId; final double quantity; final double unitFactor;
  const ReturnLineInput({required this.originalItemId,required this.quantity,required this.unitFactor});
  double get baseQuantity=>quantity*unitFactor;
  factory ReturnLineInput.fromJson(Map<String,dynamic> r)=>ReturnLineInput(originalItemId:(r['originalItemId']??r['original_item_id'])?.toString()??'',quantity:doubleValue(r['quantity']),unitFactor:doubleValue(r['unitFactor']??r['unit_factor'],1));
  Map<String,dynamic> toJson()=>{'originalItemId':originalItemId,'quantity':quantity,'unitFactor':unitFactor,'baseQuantity':baseQuantity};
  ReturnLineInput copyWith({Object?originalItemId=unset,Object?quantity=unset,Object?unitFactor=unset})=>ReturnLineInput(originalItemId:originalItemId is Unset?this.originalItemId:originalItemId as String,quantity:quantity is Unset?this.quantity:quantity as double,unitFactor:unitFactor is Unset?this.unitFactor:unitFactor as double);
}
