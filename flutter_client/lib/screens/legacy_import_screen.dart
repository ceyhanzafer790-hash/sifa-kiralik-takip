import 'package:flutter/material.dart';
import '../services/legacy_import_repository.dart';

class LegacyImportScreen extends StatefulWidget {
  const LegacyImportScreen({super.key});
  @override
  State<LegacyImportScreen> createState() => _LegacyImportScreenState();
}
class _LegacyImportScreenState extends State<LegacyImportScreen> {
  final repo = LegacyImportRepository();
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> customers = [];
  bool loading = true;
  String? error;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    setState((){loading=true;error=null;});
    try {
      final r = await Future.wait([repo.pending(), repo.customers()]);
      if(mounted) setState((){items=r[0];customers=r[1];});
    } catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> _match(Map<String,dynamic> item) async {
    String? customerId; String? rentalId; List<Map<String,dynamic>> rentals=[];
    final done = await showDialog<bool>(context: context,builder:(context)=>StatefulBuilder(builder:(context,setD)=>AlertDialog(
      title: Text(item['source_file_name'].toString()),
      content:SizedBox(width:520,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text('Tespit: ${item['detected_customer_name'] ?? 'Müşteri yok'} • ${item['detected_date'] ?? 'Tarih yok'}'),
        const SizedBox(height:12),
        DropdownButtonFormField<String>(value:customerId,isExpanded:true,decoration:const InputDecoration(labelText:'Müşteri',border:OutlineInputBorder()),items:customers.map((c)=>DropdownMenuItem(value:c['id'].toString(),child:Text(c['name'].toString()))).toList(),onChanged:(v) async {customerId=v;rentalId=null;rentals=v==null?[]:await repo.rentals(v);setD((){});}),
        const SizedBox(height:10),
        DropdownButtonFormField<String?>(value:rentalId,isExpanded:true,decoration:const InputDecoration(labelText:'Kiralama Takibi',border:OutlineInputBorder()),items:[const DropdownMenuItem<String?>(value:null,child:Text('Sadece müşteriye bağla')),...rentals.map((r)=>DropdownMenuItem<String?>(value:r['id'].toString(),child:Text('İlk çıkış: ${r['original_outbound_date']}')))],onChanged:(v)=>setD(()=>rentalId=v)),
      ]))),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Vazgeç')),
        TextButton(onPressed:() async {await repo.match(itemId:item['id'].toString(),status:'needs_review');if(context.mounted)Navigator.pop(context,true);},child:const Text('İnceleme Beklesin')),
        FilledButton(onPressed:customerId==null?null:() async {await repo.match(itemId:item['id'].toString(),customerId:customerId,rentalId:rentalId,status:'matched');if(context.mounted)Navigator.pop(context,true);},child:const Text('Eşleştir')),
      ],
    )));
    if(done==true) await _load();
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Eski Veri Eşleştirme')),
    body:RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[
      const Card(child:Padding(padding:EdgeInsets.all(14),child:Text('Eski sözleşme ve sevkiyat belgeleri emin olunmadan canlı kayda bağlanmaz.'))),
      if(loading) const LinearProgressIndicator(),
      if(error!=null) Text(error!),
      if(!loading&&items.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('Eşleştirme bekleyen kayıt yok.'))),
      ...items.map((i)=>Card(child:ListTile(leading:const Icon(Icons.rule_folder_outlined),title:Text(i['source_file_name'].toString()),subtitle:Text('${i['source_kind']} • ${i['detected_customer_name'] ?? 'Müşteri tespit edilmedi'}'),trailing:const Icon(Icons.chevron_right),onTap:()=>_match(i)))),
    ])),
  );
}
