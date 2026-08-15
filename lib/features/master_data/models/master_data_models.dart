import 'package:accounting_system/core/configs/unset.dart';
import 'package:accounting_system/core/models/model_parsers.dart';

class Party {
  final String? id;
  final String? entityId;
  final String name;
  final String? phone;
  final String type;
  final int currentBalanceMinor;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final int version;

  const Party({this.id, this.entityId, required this.name, this.phone, this.type = 'customer', this.currentBalanceMinor = 0, this.createdAt, this.updatedAt, this.deletedAt, this.version = 1});

  bool get isCustomer => type == 'customer' || type == 'both';
  bool get isSupplier => type == 'supplier' || type == 'both';
  bool get isArchived => deletedAt != null;

  factory Party.fromSql(Map<String, Object?> row) => Party(
        id: stringOrNull(row['id']), entityId: stringOrNull(row['entity_id']), name: row['name']?.toString() ?? '',
        phone: stringOrNull(row['phone']), type: row['type']?.toString() ?? 'customer', currentBalanceMinor: intValue(row['current_balance_minor']),
        createdAt: parseDate(row['created_at']), updatedAt: parseDate(row['updated_at']), deletedAt: parseDate(row['deleted_at']), version: intValue(row['version'], 1),
      );

  factory Party.fromJson(Map<String, dynamic> json) => Party(
        id: stringOrNull(json['id']), entityId: stringOrNull(json['entityId'] ?? json['entity_id']), name: json['name']?.toString() ?? '', phone: stringOrNull(json['phone']),
        type: json['type']?.toString() ?? 'customer', currentBalanceMinor: intValue(json['currentBalanceMinor'] ?? json['current_balance_minor']),
        createdAt: parseDate(json['createdAt'] ?? json['created_at']), updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']), deletedAt: parseDate(json['deletedAt'] ?? json['deleted_at']), version: intValue(json['version'], 1),
      );

  Map<String, Object?> toSql() => {if (id != null) 'id': id, 'entity_id': entityId, 'name': name, 'phone': phone, 'type': type, 'current_balance_minor': currentBalanceMinor, 'created_at': isoUtc(createdAt), 'updated_at': isoUtc(updatedAt), 'deleted_at': isoUtc(deletedAt), 'version': version};
  Map<String, dynamic> toJson() => {if (id != null) 'id': id, 'entityId': entityId, 'name': name, 'phone': phone, 'type': type, 'currentBalanceMinor': currentBalanceMinor, 'createdAt': isoUtc(createdAt), 'updatedAt': isoUtc(updatedAt), 'deletedAt': isoUtc(deletedAt), 'version': version};

  Party copyWith({Object? id = unset, Object? entityId = unset, Object? name = unset, Object? phone = unset, Object? type = unset, Object? currentBalanceMinor = unset, Object? createdAt = unset, Object? updatedAt = unset, Object? deletedAt = unset, Object? version = unset}) => Party(
        id: id is Unset ? this.id : id as String?, entityId: entityId is Unset ? this.entityId : entityId as String?, name: name is Unset ? this.name : name as String,
        phone: phone is Unset ? this.phone : phone as String?, type: type is Unset ? this.type : type as String, currentBalanceMinor: currentBalanceMinor is Unset ? this.currentBalanceMinor : currentBalanceMinor as int,
        createdAt: createdAt is Unset ? this.createdAt : createdAt as DateTime?, updatedAt: updatedAt is Unset ? this.updatedAt : updatedAt as DateTime?, deletedAt: deletedAt is Unset ? this.deletedAt : deletedAt as DateTime?, version: version is Unset ? this.version : version as int,
      );
}

class Category {
  final String? id; final String? entityId; final String name; final DateTime? createdAt; final DateTime? updatedAt; final DateTime? deletedAt; final int version;
  const Category({this.id, this.entityId, required this.name, this.createdAt, this.updatedAt, this.deletedAt, this.version = 1});
  factory Category.fromSql(Map<String, Object?> r) => Category(id:stringOrNull(r['id']),entityId:stringOrNull(r['entity_id']),name:r['name']?.toString()??'',createdAt:parseDate(r['created_at']),updatedAt:parseDate(r['updated_at']),deletedAt:parseDate(r['deleted_at']),version:intValue(r['version'],1));
  factory Category.fromJson(Map<String,dynamic> r) => Category(id:stringOrNull(r['id']),entityId:stringOrNull(r['entityId']??r['entity_id']),name:r['name']?.toString()??'',createdAt:parseDate(r['createdAt']??r['created_at']),updatedAt:parseDate(r['updatedAt']??r['updated_at']),deletedAt:parseDate(r['deletedAt']??r['deleted_at']),version:intValue(r['version'],1));
  Map<String,Object?> toSql()=>{if(id!=null)'id':id,'entity_id':entityId,'name':name,'created_at':isoUtc(createdAt),'updated_at':isoUtc(updatedAt),'deleted_at':isoUtc(deletedAt),'version':version};
  Map<String,dynamic> toJson()=>{if(id!=null)'id':id,'entityId':entityId,'name':name,'createdAt':isoUtc(createdAt),'updatedAt':isoUtc(updatedAt),'deletedAt':isoUtc(deletedAt),'version':version};
  Category copyWith({Object?id=unset,Object?entityId=unset,Object?name=unset,Object?createdAt=unset,Object?updatedAt=unset,Object?deletedAt=unset,Object?version=unset})=>Category(id:id is Unset?this.id:id as String?,entityId:entityId is Unset?this.entityId:entityId as String?,name:name is Unset?this.name:name as String,createdAt:createdAt is Unset?this.createdAt:createdAt as DateTime?,updatedAt:updatedAt is Unset?this.updatedAt:updatedAt as DateTime?,deletedAt:deletedAt is Unset?this.deletedAt:deletedAt as DateTime?,version:version is Unset?this.version:version as int);
}

class Product {
  final String? id; final String? entityId; final String? categoryId; final String name; final double minQuantity; final String? categoryName; final String? primaryUnitId; final String? primaryUnitName; final DateTime? createdAt; final DateTime? updatedAt; final DateTime? deletedAt; final int version;
  const Product({this.id,this.entityId,this.categoryId,required this.name,this.minQuantity=0,this.categoryName,this.primaryUnitId,this.primaryUnitName,this.createdAt,this.updatedAt,this.deletedAt,this.version=1});
  factory Product.fromSql(Map<String,Object?> r)=>Product(id:stringOrNull(r['id']),entityId:stringOrNull(r['entity_id']),categoryId:stringOrNull(r['category_id']),name:r['name']?.toString()??'',minQuantity:doubleValue(r['min_quantity']),categoryName:stringOrNull(r['category_name']),primaryUnitId:stringOrNull(r['primary_unit_id']),primaryUnitName:stringOrNull(r['primary_unit_name']),createdAt:parseDate(r['created_at']),updatedAt:parseDate(r['updated_at']),deletedAt:parseDate(r['deleted_at']),version:intValue(r['version'],1));
  factory Product.fromJson(Map<String,dynamic> r)=>Product(id:stringOrNull(r['id']),entityId:stringOrNull(r['entityId']??r['entity_id']),categoryId:stringOrNull(r['categoryId']??r['category_id']),name:r['name']?.toString()??'',minQuantity:doubleValue(r['minQuantity']??r['min_quantity']),categoryName:stringOrNull(r['categoryName']??r['category_name']),primaryUnitId:stringOrNull(r['primaryUnitId']??r['primary_unit_id']),primaryUnitName:stringOrNull(r['primaryUnitName']??r['primary_unit_name']),createdAt:parseDate(r['createdAt']??r['created_at']),updatedAt:parseDate(r['updatedAt']??r['updated_at']),deletedAt:parseDate(r['deletedAt']??r['deleted_at']),version:intValue(r['version'],1));
  Map<String,Object?> toSql()=>{if(id!=null)'id':id,'entity_id':entityId,'category_id':categoryId,'name':name,'min_quantity':minQuantity,'created_at':isoUtc(createdAt),'updated_at':isoUtc(updatedAt),'deleted_at':isoUtc(deletedAt),'version':version};
  Map<String,dynamic> toJson()=>{if(id!=null)'id':id,'entityId':entityId,'categoryId':categoryId,'name':name,'minQuantity':minQuantity,'categoryName':categoryName,'primaryUnitId':primaryUnitId,'primaryUnitName':primaryUnitName,'createdAt':isoUtc(createdAt),'updatedAt':isoUtc(updatedAt),'deletedAt':isoUtc(deletedAt),'version':version};
  Product copyWith({Object?id=unset,Object?entityId=unset,Object?categoryId=unset,Object?name=unset,Object?minQuantity=unset,Object?categoryName=unset,Object?primaryUnitId=unset,Object?primaryUnitName=unset,Object?createdAt=unset,Object?updatedAt=unset,Object?deletedAt=unset,Object?version=unset})=>Product(id:id is Unset?this.id:id as String?,entityId:entityId is Unset?this.entityId:entityId as String?,categoryId:categoryId is Unset?this.categoryId:categoryId as String?,name:name is Unset?this.name:name as String,minQuantity:minQuantity is Unset?this.minQuantity:minQuantity as double,categoryName:categoryName is Unset?this.categoryName:categoryName as String?,primaryUnitId:primaryUnitId is Unset?this.primaryUnitId:primaryUnitId as String?,primaryUnitName:primaryUnitName is Unset?this.primaryUnitName:primaryUnitName as String?,createdAt:createdAt is Unset?this.createdAt:createdAt as DateTime?,updatedAt:updatedAt is Unset?this.updatedAt:updatedAt as DateTime?,deletedAt:deletedAt is Unset?this.deletedAt:deletedAt as DateTime?,version:version is Unset?this.version:version as int);
}

class ProductUnit {
  final String? id; final String? entityId; final String productId; final String name; final double factor; final bool isPrimary; final DateTime? createdAt; final DateTime? updatedAt; final DateTime? deletedAt; final int version;
  const ProductUnit({this.id,this.entityId,required this.productId,required this.name,this.factor=1,this.isPrimary=false,this.createdAt,this.updatedAt,this.deletedAt,this.version=1});
  factory ProductUnit.fromSql(Map<String,Object?> r)=>ProductUnit(id:stringOrNull(r['id']),entityId:stringOrNull(r['entity_id']),productId:r['product_id']?.toString()??'',name:r['name']?.toString()??'',factor:doubleValue(r['factor'],1),isPrimary:boolValue(r['is_primary']),createdAt:parseDate(r['created_at']),updatedAt:parseDate(r['updated_at']),deletedAt:parseDate(r['deleted_at']),version:intValue(r['version'],1));
  factory ProductUnit.fromJson(Map<String,dynamic> r)=>ProductUnit(id:stringOrNull(r['id']),entityId:stringOrNull(r['entityId']??r['entity_id']),productId:(r['productId']??r['product_id'])?.toString()??'',name:r['name']?.toString()??'',factor:doubleValue(r['factor'],1),isPrimary:boolValue(r['isPrimary']??r['is_primary']),createdAt:parseDate(r['createdAt']??r['created_at']),updatedAt:parseDate(r['updatedAt']??r['updated_at']),deletedAt:parseDate(r['deletedAt']??r['deleted_at']),version:intValue(r['version'],1));
  Map<String,Object?> toSql()=>{if(id!=null)'id':id,'entity_id':entityId,'product_id':productId,'name':name,'factor':factor,'is_primary':isPrimary?1:0,'created_at':isoUtc(createdAt),'updated_at':isoUtc(updatedAt),'deleted_at':isoUtc(deletedAt),'version':version};
  Map<String,dynamic> toJson()=>{if(id!=null)'id':id,'entityId':entityId,'productId':productId,'name':name,'factor':factor,'isPrimary':isPrimary,'createdAt':isoUtc(createdAt),'updatedAt':isoUtc(updatedAt),'deletedAt':isoUtc(deletedAt),'version':version};
  ProductUnit copyWith({Object?id=unset,Object?entityId=unset,Object?productId=unset,Object?name=unset,Object?factor=unset,Object?isPrimary=unset,Object?createdAt=unset,Object?updatedAt=unset,Object?deletedAt=unset,Object?version=unset})=>ProductUnit(id:id is Unset?this.id:id as String?,entityId:entityId is Unset?this.entityId:entityId as String?,productId:productId is Unset?this.productId:productId as String,name:name is Unset?this.name:name as String,factor:factor is Unset?this.factor:factor as double,isPrimary:isPrimary is Unset?this.isPrimary:isPrimary as bool,createdAt:createdAt is Unset?this.createdAt:createdAt as DateTime?,updatedAt:updatedAt is Unset?this.updatedAt:updatedAt as DateTime?,deletedAt:deletedAt is Unset?this.deletedAt:deletedAt as DateTime?,version:version is Unset?this.version:version as int);
}

class Barcode {
  final String? id; final String? entityId; final String productUnitId; final String code; final String? unitName; final DateTime? createdAt; final DateTime? updatedAt; final DateTime? deletedAt; final int version;
  const Barcode({this.id,this.entityId,required this.productUnitId,required this.code,this.unitName,this.createdAt,this.updatedAt,this.deletedAt,this.version=1});
  factory Barcode.fromSql(Map<String,Object?> r)=>Barcode(id:stringOrNull(r['id']),entityId:stringOrNull(r['entity_id']),productUnitId:r['product_unit_id']?.toString()??'',code:r['code']?.toString()??'',unitName:stringOrNull(r['unit_name']),createdAt:parseDate(r['created_at']),updatedAt:parseDate(r['updated_at']),deletedAt:parseDate(r['deleted_at']),version:intValue(r['version'],1));
  factory Barcode.fromJson(Map<String,dynamic> r)=>Barcode(id:stringOrNull(r['id']),entityId:stringOrNull(r['entityId']??r['entity_id']),productUnitId:(r['productUnitId']??r['product_unit_id'])?.toString()??'',code:r['code']?.toString()??'',unitName:stringOrNull(r['unitName']??r['unit_name']),createdAt:parseDate(r['createdAt']??r['created_at']),updatedAt:parseDate(r['updatedAt']??r['updated_at']),deletedAt:parseDate(r['deletedAt']??r['deleted_at']),version:intValue(r['version'],1));
  Map<String,Object?> toSql()=>{if(id!=null)'id':id,'entity_id':entityId,'product_unit_id':productUnitId,'code':code,'created_at':isoUtc(createdAt),'updated_at':isoUtc(updatedAt),'deleted_at':isoUtc(deletedAt),'version':version};
  Map<String,dynamic> toJson()=>{if(id!=null)'id':id,'entityId':entityId,'productUnitId':productUnitId,'code':code,'unitName':unitName,'createdAt':isoUtc(createdAt),'updatedAt':isoUtc(updatedAt),'deletedAt':isoUtc(deletedAt),'version':version};
  Barcode copyWith({Object?id=unset,Object?entityId=unset,Object?productUnitId=unset,Object?code=unset,Object?unitName=unset,Object?createdAt=unset,Object?updatedAt=unset,Object?deletedAt=unset,Object?version=unset})=>Barcode(id:id is Unset?this.id:id as String?,entityId:entityId is Unset?this.entityId:entityId as String?,productUnitId:productUnitId is Unset?this.productUnitId:productUnitId as String,code:code is Unset?this.code:code as String,unitName:unitName is Unset?this.unitName:unitName as String?,createdAt:createdAt is Unset?this.createdAt:createdAt as DateTime?,updatedAt:updatedAt is Unset?this.updatedAt:updatedAt as DateTime?,deletedAt:deletedAt is Unset?this.deletedAt:deletedAt as DateTime?,version:version is Unset?this.version:version as int);
}

class ProductSpecification {
  final String? id; final String? entityId; final String productId; final String title; final String value; final DateTime? createdAt; final DateTime? updatedAt; final DateTime? deletedAt; final int version;
  const ProductSpecification({this.id,this.entityId,required this.productId,required this.title,required this.value,this.createdAt,this.updatedAt,this.deletedAt,this.version=1});
  factory ProductSpecification.fromSql(Map<String,Object?> r)=>ProductSpecification(id:stringOrNull(r['id']),entityId:stringOrNull(r['entity_id']),productId:r['product_id']?.toString()??'',title:r['title']?.toString()??'',value:r['value']?.toString()??'',createdAt:parseDate(r['created_at']),updatedAt:parseDate(r['updated_at']),deletedAt:parseDate(r['deleted_at']),version:intValue(r['version'],1));
  factory ProductSpecification.fromJson(Map<String,dynamic> r)=>ProductSpecification(id:stringOrNull(r['id']),entityId:stringOrNull(r['entityId']??r['entity_id']),productId:(r['productId']??r['product_id'])?.toString()??'',title:r['title']?.toString()??'',value:r['value']?.toString()??'',createdAt:parseDate(r['createdAt']??r['created_at']),updatedAt:parseDate(r['updatedAt']??r['updated_at']),deletedAt:parseDate(r['deletedAt']??r['deleted_at']),version:intValue(r['version'],1));
  Map<String,Object?> toSql()=>{if(id!=null)'id':id,'entity_id':entityId,'product_id':productId,'title':title,'value':value,'created_at':isoUtc(createdAt),'updated_at':isoUtc(updatedAt),'deleted_at':isoUtc(deletedAt),'version':version};
  Map<String,dynamic> toJson()=>{if(id!=null)'id':id,'entityId':entityId,'productId':productId,'title':title,'value':value,'createdAt':isoUtc(createdAt),'updatedAt':isoUtc(updatedAt),'deletedAt':isoUtc(deletedAt),'version':version};
  ProductSpecification copyWith({Object?id=unset,Object?entityId=unset,Object?productId=unset,Object?title=unset,Object?value=unset,Object?createdAt=unset,Object?updatedAt=unset,Object?deletedAt=unset,Object?version=unset})=>ProductSpecification(id:id is Unset?this.id:id as String?,entityId:entityId is Unset?this.entityId:entityId as String?,productId:productId is Unset?this.productId:productId as String,title:title is Unset?this.title:title as String,value:value is Unset?this.value:value as String,createdAt:createdAt is Unset?this.createdAt:createdAt as DateTime?,updatedAt:updatedAt is Unset?this.updatedAt:updatedAt as DateTime?,deletedAt:deletedAt is Unset?this.deletedAt:deletedAt as DateTime?,version:version is Unset?this.version:version as int);
}

class Warehouse {
  final String? id; final String? entityId; final String name; final DateTime? createdAt; final DateTime? updatedAt; final DateTime? deletedAt; final int version;
  const Warehouse({this.id,this.entityId,required this.name,this.createdAt,this.updatedAt,this.deletedAt,this.version=1});
  factory Warehouse.fromSql(Map<String,Object?> r)=>Warehouse(id:stringOrNull(r['id']),entityId:stringOrNull(r['entity_id']),name:r['name']?.toString()??'',createdAt:parseDate(r['created_at']),updatedAt:parseDate(r['updated_at']),deletedAt:parseDate(r['deleted_at']),version:intValue(r['version'],1));
  factory Warehouse.fromJson(Map<String,dynamic> r)=>Warehouse(id:stringOrNull(r['id']),entityId:stringOrNull(r['entityId']??r['entity_id']),name:r['name']?.toString()??'',createdAt:parseDate(r['createdAt']??r['created_at']),updatedAt:parseDate(r['updatedAt']??r['updated_at']),deletedAt:parseDate(r['deletedAt']??r['deleted_at']),version:intValue(r['version'],1));
  Map<String,Object?> toSql()=>{if(id!=null)'id':id,'entity_id':entityId,'name':name,'created_at':isoUtc(createdAt),'updated_at':isoUtc(updatedAt),'deleted_at':isoUtc(deletedAt),'version':version};
  Map<String,dynamic> toJson()=>{if(id!=null)'id':id,'entityId':entityId,'name':name,'createdAt':isoUtc(createdAt),'updatedAt':isoUtc(updatedAt),'deletedAt':isoUtc(deletedAt),'version':version};
  Warehouse copyWith({Object?id=unset,Object?entityId=unset,Object?name=unset,Object?createdAt=unset,Object?updatedAt=unset,Object?deletedAt=unset,Object?version=unset})=>Warehouse(id:id is Unset?this.id:id as String?,entityId:entityId is Unset?this.entityId:entityId as String?,name:name is Unset?this.name:name as String,createdAt:createdAt is Unset?this.createdAt:createdAt as DateTime?,updatedAt:updatedAt is Unset?this.updatedAt:updatedAt as DateTime?,deletedAt:deletedAt is Unset?this.deletedAt:deletedAt as DateTime?,version:version is Unset?this.version:version as int);
}

class FinancialYear {
  final String? id; final String? entityId; final String name; final DateTime startsOn; final DateTime endsOn; final bool isOpen; final DateTime? closedAt; final String? closedBy; final DateTime? createdAt; final DateTime? updatedAt; final int version;
  const FinancialYear({this.id,this.entityId,required this.name,required this.startsOn,required this.endsOn,this.isOpen=true,this.closedAt,this.closedBy,this.createdAt,this.updatedAt,this.version=1});
  factory FinancialYear.fromSql(Map<String,Object?> r)=>FinancialYear(id:stringOrNull(r['id']),entityId:stringOrNull(r['entity_id']),name:r['name']?.toString()??'',startsOn:parseDate(r['starts_on'])??DateTime.fromMillisecondsSinceEpoch(0),endsOn:parseDate(r['ends_on'])??DateTime.fromMillisecondsSinceEpoch(0),isOpen:boolValue(r['is_open']),closedAt:parseDate(r['closed_at']),closedBy:stringOrNull(r['closed_by']),createdAt:parseDate(r['created_at']),updatedAt:parseDate(r['updated_at']),version:intValue(r['version'],1));
  factory FinancialYear.fromJson(Map<String,dynamic> r)=>FinancialYear(id:stringOrNull(r['id']),entityId:stringOrNull(r['entityId']??r['entity_id']),name:r['name']?.toString()??'',startsOn:parseDate(r['startsOn']??r['starts_on'])??DateTime.fromMillisecondsSinceEpoch(0),endsOn:parseDate(r['endsOn']??r['ends_on'])??DateTime.fromMillisecondsSinceEpoch(0),isOpen:boolValue(r['isOpen']??r['is_open'],true),closedAt:parseDate(r['closedAt']??r['closed_at']),closedBy:stringOrNull(r['closedBy']??r['closed_by']),createdAt:parseDate(r['createdAt']??r['created_at']),updatedAt:parseDate(r['updatedAt']??r['updated_at']),version:intValue(r['version'],1));
  Map<String,Object?> toSql()=>{if(id!=null)'id':id,'entity_id':entityId,'name':name,'starts_on':isoUtc(startsOn),'ends_on':isoUtc(endsOn),'is_open':isOpen?1:0,'closed_at':isoUtc(closedAt),'closed_by':closedBy,'created_at':isoUtc(createdAt),'updated_at':isoUtc(updatedAt),'version':version};
  Map<String,dynamic> toJson()=>{if(id!=null)'id':id,'entityId':entityId,'name':name,'startsOn':isoUtc(startsOn),'endsOn':isoUtc(endsOn),'isOpen':isOpen,'closedAt':isoUtc(closedAt),'closedBy':closedBy,'createdAt':isoUtc(createdAt),'updatedAt':isoUtc(updatedAt),'version':version};
  FinancialYear copyWith({Object?id=unset,Object?entityId=unset,Object?name=unset,Object?startsOn=unset,Object?endsOn=unset,Object?isOpen=unset,Object?closedAt=unset,Object?closedBy=unset,Object?createdAt=unset,Object?updatedAt=unset,Object?version=unset})=>FinancialYear(id:id is Unset?this.id:id as String?,entityId:entityId is Unset?this.entityId:entityId as String?,name:name is Unset?this.name:name as String,startsOn:startsOn is Unset?this.startsOn:startsOn as DateTime,endsOn:endsOn is Unset?this.endsOn:endsOn as DateTime,isOpen:isOpen is Unset?this.isOpen:isOpen as bool,closedAt:closedAt is Unset?this.closedAt:closedAt as DateTime?,closedBy:closedBy is Unset?this.closedBy:closedBy as String?,createdAt:createdAt is Unset?this.createdAt:createdAt as DateTime?,updatedAt:updatedAt is Unset?this.updatedAt:updatedAt as DateTime?,version:version is Unset?this.version:version as int);
}

class ProductDetailsData {
  final List<ProductUnit> units;
  final List<Barcode> barcodes;
  final List<ProductSpecification> specifications;
  const ProductDetailsData({required this.units,required this.barcodes,required this.specifications});
}
