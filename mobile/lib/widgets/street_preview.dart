import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/route_response.dart';
import '../theme.dart';

class StreetPreview extends StatelessWidget {
  final RouteStep step; final VoidCallback onClose; final bool isDark; final bool isEditorial;
  const StreetPreview({super.key, required this.step, required this.onClose, this.isDark=false, this.isEditorial=false});
  Future<void> _openStreetView() async {
    final lat=step.lat, lng=step.lng;
    final urls=[Uri.parse('google.streetview:cbll=$lat,$lng'), Uri.parse('https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$lat,$lng'), Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng')];
    for(final u in urls){ if(await canLaunchUrl(u)){ await launchUrl(u, mode:LaunchMode.externalApplication); return; } }
    await launchUrl(urls.last, mode:LaunchMode.externalApplication);
  }
  Future<void> _openDirections() async {
    final url=Uri.parse('https://www.google.com/maps/search/?api=1&query=${step.lat},${step.lng}');
    if(await canLaunchUrl(url)) await launchUrl(url, mode:LaunchMode.externalApplication);
  }
  @override Widget build(BuildContext context){
    final ll=LatLng(step.lat,step.lng); final isCampus=step.isCustomPath;
    final bg=isEditorial?Editorial.card:(isDark?DarkPremium.card:Colors.white);
    final txt=isEditorial?Editorial.ink:(isDark?DarkPremium.textPrimary:GoogleColors.textPrimary);
    final sub=isEditorial?Editorial.inkSecondary:(isDark?DarkPremium.textSecondary:GoogleColors.textSecondary);
    final ter=isEditorial?Editorial.inkTertiary:(isDark?DarkPremium.textTertiary:GoogleColors.textTertiary);
    final border=isEditorial?Editorial.border:(isDark?DarkPremium.border:GoogleColors.border);
    final surf=isEditorial?Editorial.paperDark:(isDark?DarkPremium.cardElevated:GoogleColors.surface);
    final accent=isEditorial?Editorial.coral:(isDark?DarkPremium.neonBlue:GoogleColors.blue);
    String tileUrl(){ if(isDark) return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'; if(isEditorial) return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png'; return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'; }
    return Container(
      decoration:BoxDecoration(color:bg, borderRadius:const BorderRadius.vertical(top:Radius.circular(20)), border:Border(top:BorderSide(color:border)), boxShadow:[BoxShadow(color:Colors.black.withAlpha(isEditorial?18:30), blurRadius:16, offset:Offset(0,-4))]),
      child:Column(mainAxisSize:MainAxisSize.min, children:[
        Container(margin:const EdgeInsets.only(top:8), width:32,height:4, decoration:BoxDecoration(color:isEditorial?Editorial.divider:(isDark?DarkPremium.divider:GoogleColors.divider), borderRadius:BorderRadius.circular(2))),
        ClipRRect(borderRadius:BorderRadius.circular(12), child:Container(margin:const EdgeInsets.fromLTRB(16,12,16,0), height:140, decoration:BoxDecoration(border:Border.all(color:border), borderRadius:BorderRadius.circular(12)), child:Stack(children:[
          FlutterMap(options:MapOptions(initialCenter:ll, initialZoom:19, interactionOptions:const InteractionOptions(flags:InteractiveFlag.none)), children:[
            TileLayer(urlTemplate:tileUrl(), subdomains:(isDark||isEditorial)?['a','b','c','d']:[], userAgentPackageName:'com.runit.maps'),
            MarkerLayer(markers:[Marker(point:ll, width:36,height:36, child:_pin(isCampus))]),
          ]),
          Positioned(left:8,top:8, child:Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4), decoration:BoxDecoration(color:isEditorial?Editorial.navy:(isDark?DarkPremium.neonBlue:const Color(0xFF323232)), borderRadius:BorderRadius.circular(12)), child:Row(mainAxisSize:MainAxisSize.min, children:[Icon(Icons.streetview, size:14, color:isEditorial||isDark?Colors.white:Colors.white), const SizedBox(width:4), Text('Step ${step.stepNumber}', style:TextStyle(color:Colors.white, fontSize:12, fontWeight:FontWeight.w700, fontStyle:FontStyle.italic))]))),
          Positioned(right:8,bottom:8, child:Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4), decoration:BoxDecoration(color:bg, borderRadius:BorderRadius.circular(20), border:Border.all(color:border)), child:Row(mainAxisSize:MainAxisSize.min, children:[Icon(Icons.my_location, size:12, color:accent), const SizedBox(width:4), Text('${ll.latitude.toStringAsFixed(5)}, ${ll.longitude.toStringAsFixed(5)}', style:TextStyle(fontSize:11, color:sub))]))),
        ]))),
        Padding(padding:const EdgeInsets.fromLTRB(16,12,16,12), child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          Row(children:[
            Container(width:28,height:28, decoration:BoxDecoration(color:isCampus?(isEditorial?Editorial.mustard.withAlpha(30):(isDark?DarkPremium.neonYellow.withAlpha(30):GoogleColors.yellow.withAlpha(40))):surf, shape:BoxShape.circle, border:Border.all(color:isCampus?(isEditorial?Editorial.mustard:(isDark?DarkPremium.neonYellow:GoogleColors.yellow)):border)), child:Icon(_icon(step.direction), size:16, color:isCampus?(isEditorial?Editorial.navy:(isDark?DarkPremium.neonYellow:const Color(0xFF7A4A00))):sub)),
            const SizedBox(width:8), Expanded(child:Text(step.instruction.isNotEmpty?step.instruction:'Continue', style:TextStyle(fontSize:14, fontWeight:FontWeight.w600, color:txt, fontStyle:isEditorial?FontStyle.italic:FontStyle.normal), maxLines:2)),
            IconButton(onPressed:onClose, icon:Icon(Icons.close, size:20, color:sub), style:IconButton.styleFrom(backgroundColor:surf)),
          ]),
          if(step.streetName.isNotEmpty) Padding(padding:const EdgeInsets.only(left:36,top:2), child:Text(step.streetName, style:TextStyle(fontSize:13, color:sub))),
          Padding(padding:const EdgeInsets.only(left:36,top:4), child:Text('${step.distanceMeters.toStringAsFixed(0)} m · ${(step.durationSeconds/60).toStringAsFixed(0)} min${isCampus?' · Campus path':''}', style:TextStyle(fontSize:12, color:ter))),
          const SizedBox(height:12),
          Row(children:[
            Expanded(child:FilledButton.icon(onPressed:_openStreetView, icon:const Icon(Icons.panorama, size:18), label:const Text('Peek street'), style:FilmedStyle.call(isDark:isDark, isEditorial:isEditorial))),
            const SizedBox(width:8),
            Expanded(child:OutlinedButton.icon(onPressed:_openDirections, icon:Icon(Icons.near_me, size:18, color:accent), label:Text('Go', style:TextStyle(color:accent)), style:OutlinedButton.styleFrom(side:BorderSide(color:border), padding:const EdgeInsets.symmetric(vertical:10), shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24))))),
          ]),
          const SizedBox(height:4), Center(child:Text('Opens in Maps — no key needed', style:TextStyle(fontSize:11, color:ter, fontStyle:FontStyle.italic))),
        ])),
      ]),
    );
  }
  Widget _pin(bool isCampus){
    final c=isCampus?(isEditorial?Editorial.mustard:(isDark?DarkPremium.neonYellow:GoogleColors.yellow)):(isEditorial?Editorial.coral:(isDark?DarkPremium.neonBlue:GoogleColors.blue));
    return Container(decoration:BoxDecoration(color:c, shape:BoxShape.circle, border:Border.all(color:Colors.white, width:2), boxShadow:[BoxShadow(color:c.withAlpha(60), blurRadius:8)]), child:Icon(isCampus?Icons.school:Icons.location_on, color:isEditorial?Editorial.navy:(isCampus?DarkPremium.bg:Colors.white), size:20));
  }
  IconData _icon(String d){ const m={'north':Icons.arrow_upward,'south':Icons.arrow_downward,'east':Icons.arrow_forward,'west':Icons.arrow_back,'northeast':Icons.north_east,'northwest':Icons.north_west,'southeast':Icons.south_east,'southwest':Icons.south_west,'straight':Icons.arrow_upward}; return m[d]??Icons.arrow_upward; }
}
class FilmedStyle {
  static ButtonStyle call({bool isDark=false, bool isEditorial=false}){
    final bg=isEditorial?Editorial.coral:(isDark?DarkPremium.neonBlue:GoogleColors.blue);
    return FilledButton.styleFrom(backgroundColor:bg, foregroundColor:Colors.white, padding:const EdgeInsets.symmetric(vertical:10), shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)));
  }
}
