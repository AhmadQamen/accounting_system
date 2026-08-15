import 'package:accounting_system/core/configs/unset.dart';
import 'package:accounting_system/core/models/model_parsers.dart';

class InventoryItem {
  final String? id;
  final String? entityId;
  final String productId;
  final String warehouseId;
  final double currentQuantity;
  final int inventoryValueMinor;
  final String? productName;
  final double minQuantity;
  final String? warehouseName;
  final String? primaryUnitId;
  final String? primaryUnitName;
  final double primaryUnitFactor;
  final DateTime? updatedAt;
  final int version;

  const InventoryItem({this.id,this.entityId,required this.productId,required this.warehouseId,this.currentQuantity=0,this.inventoryValueMinor=0,this.productName,this.minQuantity=0,this.warehouseName,this.primaryUnitId,this.primaryUnitName,this.primaryUnitFactor=1,this.updatedAt,this.version=1});

  bool get isLowStock => minQuantity > 0 && currentQuantity <= minQuantity;
  int get averageUnitCostMinor => currentQuantity == 0 ? 0 : (inventoryValueMinor / currentQuantity).round();

  factory InventoryItem.fromSql(Map<String,Object?> r)=>InventoryItem(
    id:stringOrNull(r['inventory_item_id']??r['id']), entityId:stringOrNull(r['entity_id']), productId:r['product_id']?.toString()??'', warehouseId:r['warehouse_id']?.toString()??'',
    currentQuantity:doubleValue(r['current_quantity']), inventoryValueMinor:intValue(r['inventory_value_minor']), productName:stringOrNull(r['product_name']), minQuantity:doubleValue(r['min_quantity']), warehouseName:stringOrNull(r['warehouse_name']),
    primaryUnitId:stringOrNull(r['primary_unit_id']), primaryUnitName:stringOrNull(r['primary_unit_name']), primaryUnitFactor:doubleValue(r['primary_unit_factor'],1), updatedAt:parseDate(r['updated_at']), version:intValue(r['version'],1),
  );
  factory InventoryItem.fromJson(Map<String,dynamic> r)=>InventoryItem(id:stringOrNull(r['id']),entityId:stringOrNull(r['entityId']??r['entity_id']),productId:(r['productId']??r['product_id'])?.toString()??'',warehouseId:(r['warehouseId']??r['warehouse_id'])?.toString()??'',currentQuantity:doubleValue(r['currentQuantity']??r['current_quantity']),inventoryValueMinor:intValue(r['inventoryValueMinor']??r['inventory_value_minor']),productName:stringOrNull(r['productName']??r['product_name']),minQuantity:doubleValue(r['minQuantity']??r['min_quantity']),warehouseName:stringOrNull(r['warehouseName']??r['warehouse_name']),primaryUnitId:stringOrNull(r['primaryUnitId']??r['primary_unit_id']),primaryUnitName:stringOrNull(r['primaryUnitName']??r['primary_unit_name']),primaryUnitFactor:doubleValue(r['primaryUnitFactor']??r['primary_unit_factor'],1),updatedAt:parseDate(r['updatedAt']??r['updated_at']),version:intValue(r['version'],1));
  Map<String,Object?> toSql()=>{if(id!=null)'id':id,'entity_id':entityId,'product_id':productId,'warehouse_id':warehouseId,'current_quantity':currentQuantity,'inventory_value_minor':inventoryValueMinor,'updated_at':isoUtc(updatedAt),'version':version};
  Map<String,dynamic> toJson()=>{if(id!=null)'id':id,'entityId':entityId,'productId':productId,'warehouseId':warehouseId,'currentQuantity':currentQuantity,'inventoryValueMinor':inventoryValueMinor,'productName':productName,'minQuantity':minQuantity,'warehouseName':warehouseName,'primaryUnitId':primaryUnitId,'primaryUnitName':primaryUnitName,'primaryUnitFactor':primaryUnitFactor,'updatedAt':isoUtc(updatedAt),'version':version};
  InventoryItem copyWith({Object?id=unset,Object?entityId=unset,Object?productId=unset,Object?warehouseId=unset,Object?currentQuantity=unset,Object?inventoryValueMinor=unset,Object?productName=unset,Object?minQuantity=unset,Object?warehouseName=unset,Object?primaryUnitId=unset,Object?primaryUnitName=unset,Object?primaryUnitFactor=unset,Object?updatedAt=unset,Object?version=unset})=>InventoryItem(id:id is Unset?this.id:id as String?,entityId:entityId is Unset?this.entityId:entityId as String?,productId:productId is Unset?this.productId:productId as String,warehouseId:warehouseId is Unset?this.warehouseId:warehouseId as String,currentQuantity:currentQuantity is Unset?this.currentQuantity:currentQuantity as double,inventoryValueMinor:inventoryValueMinor is Unset?this.inventoryValueMinor:inventoryValueMinor as int,productName:productName is Unset?this.productName:productName as String?,minQuantity:minQuantity is Unset?this.minQuantity:minQuantity as double,warehouseName:warehouseName is Unset?this.warehouseName:warehouseName as String?,primaryUnitId:primaryUnitId is Unset?this.primaryUnitId:primaryUnitId as String?,primaryUnitName:primaryUnitName is Unset?this.primaryUnitName:primaryUnitName as String?,primaryUnitFactor:primaryUnitFactor is Unset?this.primaryUnitFactor:primaryUnitFactor as double,updatedAt:updatedAt is Unset?this.updatedAt:updatedAt as DateTime?,version:version is Unset?this.version:version as int);
}

class SellableProduct {
  final String productId; final String productName; final String productUnitId; final String unitName; final double factor; final String? inventoryItemId; final double currentQuantity; final int inventoryValueMinor;
  const SellableProduct({required this.productId,required this.productName,required this.productUnitId,required this.unitName,this.factor=1,this.inventoryItemId,this.currentQuantity=0,this.inventoryValueMinor=0});
  factory SellableProduct.fromSql(Map<String,Object?> r)=>SellableProduct(productId:r['product_id']?.toString()??'',productName:r['product_name']?.toString()??'',productUnitId:r['product_unit_id']?.toString()??'',unitName:r['unit_name']?.toString()??'',factor:doubleValue(r['factor'],1),inventoryItemId:stringOrNull(r['inventory_item_id']),currentQuantity:doubleValue(r['current_quantity']),inventoryValueMinor:intValue(r['inventory_value_minor']));
  factory SellableProduct.fromJson(Map<String,dynamic> r)=>SellableProduct(productId:(r['productId']??r['product_id'])?.toString()??'',productName:(r['productName']??r['product_name'])?.toString()??'',productUnitId:(r['productUnitId']??r['product_unit_id'])?.toString()??'',unitName:(r['unitName']??r['unit_name'])?.toString()??'',factor:doubleValue(r['factor'],1),inventoryItemId:stringOrNull(r['inventoryItemId']??r['inventory_item_id']),currentQuantity:doubleValue(r['currentQuantity']??r['current_quantity']),inventoryValueMinor:intValue(r['inventoryValueMinor']??r['inventory_value_minor']));
  Map<String,dynamic> toJson()=>{'productId':productId,'productName':productName,'productUnitId':productUnitId,'unitName':unitName,'factor':factor,'inventoryItemId':inventoryItemId,'currentQuantity':currentQuantity,'inventoryValueMinor':inventoryValueMinor};
  SellableProduct copyWith({Object?productId=unset,Object?productName=unset,Object?productUnitId=unset,Object?unitName=unset,Object?factor=unset,Object?inventoryItemId=unset,Object?currentQuantity=unset,Object?inventoryValueMinor=unset})=>SellableProduct(productId:productId is Unset?this.productId:productId as String,productName:productName is Unset?this.productName:productName as String,productUnitId:productUnitId is Unset?this.productUnitId:productUnitId as String,unitName:unitName is Unset?this.unitName:unitName as String,factor:factor is Unset?this.factor:factor as double,inventoryItemId:inventoryItemId is Unset?this.inventoryItemId:inventoryItemId as String?,currentQuantity:currentQuantity is Unset?this.currentQuantity:currentQuantity as double,inventoryValueMinor:inventoryValueMinor is Unset?this.inventoryValueMinor:inventoryValueMinor as int);
}

class InventoryMovement {
  final String? id; final String inventoryItemId; final String movementType; final double quantityDelta; final int valueDeltaMinor; final String? productName; final String? warehouseName; final String? referenceType; final String? referenceId; final DateTime? occurredAt;
  const InventoryMovement({this.id,required this.inventoryItemId,required this.movementType,this.quantityDelta=0,this.valueDeltaMinor=0,this.productName,this.warehouseName,this.referenceType,this.referenceId,this.occurredAt});
  factory InventoryMovement.fromSql(Map<String,Object?> r)=>InventoryMovement(id:stringOrNull(r['id']),inventoryItemId:r['inventory_item_id']?.toString()??'',movementType:r['movement_type']?.toString()??'',quantityDelta:doubleValue(r['quantity_delta']),valueDeltaMinor:intValue(r['value_delta_minor']),productName:stringOrNull(r['product_name']),warehouseName:stringOrNull(r['warehouse_name']),referenceType:stringOrNull(r['reference_type']),referenceId:stringOrNull(r['reference_id']),occurredAt:parseDate(r['occurred_at']));
  factory InventoryMovement.fromJson(Map<String,dynamic> r)=>InventoryMovement(id:stringOrNull(r['id']),inventoryItemId:(r['inventoryItemId']??r['inventory_item_id'])?.toString()??'',movementType:(r['movementType']??r['movement_type'])?.toString()??'',quantityDelta:doubleValue(r['quantityDelta']??r['quantity_delta']),valueDeltaMinor:intValue(r['valueDeltaMinor']??r['value_delta_minor']),productName:stringOrNull(r['productName']??r['product_name']),warehouseName:stringOrNull(r['warehouseName']??r['warehouse_name']),referenceType:stringOrNull(r['referenceType']??r['reference_type']),referenceId:stringOrNull(r['referenceId']??r['reference_id']),occurredAt:parseDate(r['occurredAt']??r['occurred_at']));
  Map<String,Object?> toSql()=>{if(id!=null)'id':id,'inventory_item_id':inventoryItemId,'movement_type':movementType,'quantity_delta':quantityDelta,'value_delta_minor':valueDeltaMinor,'reference_type':referenceType,'reference_id':referenceId,'occurred_at':isoUtc(occurredAt)};
  Map<String,dynamic> toJson()=>{if(id!=null)'id':id,'inventoryItemId':inventoryItemId,'movementType':movementType,'quantityDelta':quantityDelta,'valueDeltaMinor':valueDeltaMinor,'productName':productName,'warehouseName':warehouseName,'referenceType':referenceType,'referenceId':referenceId,'occurredAt':isoUtc(occurredAt)};
  InventoryMovement copyWith({Object?id=unset,Object?inventoryItemId=unset,Object?movementType=unset,Object?quantityDelta=unset,Object?valueDeltaMinor=unset,Object?productName=unset,Object?warehouseName=unset,Object?referenceType=unset,Object?referenceId=unset,Object?occurredAt=unset})=>InventoryMovement(id:id is Unset?this.id:id as String?,inventoryItemId:inventoryItemId is Unset?this.inventoryItemId:inventoryItemId as String,movementType:movementType is Unset?this.movementType:movementType as String,quantityDelta:quantityDelta is Unset?this.quantityDelta:quantityDelta as double,valueDeltaMinor:valueDeltaMinor is Unset?this.valueDeltaMinor:valueDeltaMinor as int,productName:productName is Unset?this.productName:productName as String?,warehouseName:warehouseName is Unset?this.warehouseName:warehouseName as String?,referenceType:referenceType is Unset?this.referenceType:referenceType as String?,referenceId:referenceId is Unset?this.referenceId:referenceId as String?,occurredAt:occurredAt is Unset?this.occurredAt:occurredAt as DateTime?);
}

class InventoryCacheVerification {
  final bool ok; final int mismatchCount; final String details;
  const InventoryCacheVerification({required this.ok,this.mismatchCount=0,this.details=''});
}

class InventoryAdjustmentInput {
  final String inventoryItemId; final String productUnitId; final double countedQuantity; final double unitFactor;
  const InventoryAdjustmentInput({required this.inventoryItemId,required this.productUnitId,required this.countedQuantity,this.unitFactor=1});
  Map<String,Object?> toSql()=>{'inventory_item_id':inventoryItemId,'product_unit_id':productUnitId,'counted_quantity':countedQuantity,'unit_factor':unitFactor};
  Map<String,dynamic> toJson()=>{'inventoryItemId':inventoryItemId,'productUnitId':productUnitId,'countedQuantity':countedQuantity,'unitFactor':unitFactor};
  InventoryAdjustmentInput copyWith({Object?inventoryItemId=unset,Object?productUnitId=unset,Object?countedQuantity=unset,Object?unitFactor=unset})=>InventoryAdjustmentInput(inventoryItemId:inventoryItemId is Unset?this.inventoryItemId:inventoryItemId as String,productUnitId:productUnitId is Unset?this.productUnitId:productUnitId as String,countedQuantity:countedQuantity is Unset?this.countedQuantity:countedQuantity as double,unitFactor:unitFactor is Unset?this.unitFactor:unitFactor as double);
}

class InventoryTransferInput {
  final String productId; final String productUnitId; final double quantity; final double unitFactor;
  const InventoryTransferInput({required this.productId,required this.productUnitId,required this.quantity,required this.unitFactor});
  double get baseQuantity=>quantity*unitFactor;
  Map<String,Object?> toSql()=>{'product_id':productId,'product_unit_id':productUnitId,'quantity':quantity,'unit_factor':unitFactor,'base_quantity':baseQuantity};
  Map<String,dynamic> toJson()=>{'productId':productId,'productUnitId':productUnitId,'quantity':quantity,'unitFactor':unitFactor,'baseQuantity':baseQuantity};
  InventoryTransferInput copyWith({Object?productId=unset,Object?productUnitId=unset,Object?quantity=unset,Object?unitFactor=unset})=>InventoryTransferInput(productId:productId is Unset?this.productId:productId as String,productUnitId:productUnitId is Unset?this.productUnitId:productUnitId as String,quantity:quantity is Unset?this.quantity:quantity as double,unitFactor:unitFactor is Unset?this.unitFactor:unitFactor as double);
}
